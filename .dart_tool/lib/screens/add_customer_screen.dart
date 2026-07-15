import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:async';
import 'package:country_state_city/country_state_city.dart' as csc;
import '../theme/app_theme.dart';
import '../widgets/crm_text_field.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import 'edit_visit_screen.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/services.dart';

class AddCustomerScreen extends StatefulWidget {
  final List<Map<String, dynamic>> employees;
  final List<Map<String, dynamic>> customers;
  final Map<String, dynamic>? customerToEdit;
  final bool isAddingVisit;

  const AddCustomerScreen({
    super.key,
    required this.employees,
    required this.customers,
    this.customerToEdit,
    this.isAddingVisit = false,
  });

  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  // Personal Information
  final _customerNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _visitNumberController = TextEditingController();

  // Visit fields (shared between edit and new visit)
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

  // Visit state
  // Customer profile photo
  File? _customerImageFile;
  String? _existingCustomerImageUrl;

  // Visit state
  String _conclusion = 'Pending';
  List<File> _goldImages = [];
  List<File> _diamondImages = [];
  List<File> _polkiImages = [];
  TimeOfDay? _reminderTime;

  // existing (already-uploaded) image URLs for the visit currently
  List<String> _existingGoldImageUrls = [];
  List<String> _existingDiamondImageUrls = [];
  List<String> _existingPolkiImageUrls = [];

  // Visit history (for edit mode)
  List<Map<String, dynamic>> _visits = [];
  List<bool> _visitExpanded = [];

  // Other state
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
  final _customCityController = TextEditingController();

  String? _pendingCountryName;
  String? _pendingStateName;
  String? _pendingCityName;

  List<Map<String, dynamic>> _branches = [];
  bool _isLoadingBranches = false;
  bool _isLoading = false;

  bool _showNewVisitForm = false;

  final ImagePicker _picker = ImagePicker();

  bool get _isEditMode => widget.customerToEdit != null;
  bool get _isAddingVisit => _showNewVisitForm && _isEditMode;

  // ---------- Conclusion Mapping ----------
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

  String _getEmployeeName(dynamic idOrName) {
    if (idOrName == null) return 'Not specified';
    final value = idOrName.toString().trim();
    if (value.isEmpty) return 'Not specified';

    for (final employee in widget.employees) {
      final empId = employee['_id']?.toString() ?? employee['id']?.toString();
      if (empId != null && empId == value) {
        return employee['name']?.toString() ?? 'Unknown';
      }
    }
    return value;
  }

  @override
  void initState() {
    super.initState();
    _customerNameController.addListener(_forceUppercaseName);
    _loadBranches();
    _loadOptions().then((_) {
      if (_isEditMode) {
        _prefillForEdit(widget.customerToEdit!);
      } else {
        _visitNumberController.text = '1';
      }

      _loadCountries();

      if (widget.isAddingVisit && _isEditMode) {
        _showNewVisitForm = true;
        _clearNewVisitFields();
        _visitNumberController.text = (_visits.length + 1).toString();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      }
    });
  }

  void _forceUppercaseName() {
    final text = _customerNameController.text;
    final upper = text.toUpperCase();
    if (text != upper) {
      final selection = _customerNameController.selection;
      _customerNameController.value = _customerNameController.value.copyWith(
        text: upper,
        selection: selection,
      );
    }
  }

  Future<void> _loadOptions() async {
    try {
      final apiProfessions = await ApiService().getDistinctProfessions();
      final apiCommunities = await ApiService().getDistinctCommunities();

      setState(() {
        _professionOptionsList = List.from(_defaultProfessionOptions);
        _communityOptionsList = List.from(_defaultCommunityOptions);

        for (final p in apiProfessions) {
          if (!_professionOptionsList.contains(p)) {
            _professionOptionsList.add(p);
          }
        }
        for (final c in apiCommunities) {
          if (!_communityOptionsList.contains(c)) {
            _communityOptionsList.add(c);
          }
        }
      });
    } catch (e) {
      setState(() {
        _professionOptionsList = List.from(_defaultProfessionOptions);
        _communityOptionsList = List.from(_defaultCommunityOptions);
      });
    }
  }

  // ================= COUNTRY / STATE / CITY (dynamic) =================

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
      } else if (!_isEditMode) {
        initialCountry = _countryList.firstWhere(
          (c) => c.isoCode == 'IN',
          orElse: () => countries.first,
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
        final match = states.where(
          (s) => s.name.toLowerCase() == _pendingStateName!.toLowerCase(),
        );
        if (match.isNotEmpty) initialState = match.first;
      } else if (!_isEditMode && countryIsoCode == 'IN') {
        final match = states.where((s) => s.name == 'Punjab');
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
        final match = cities.where(
          (c) => c.name.toLowerCase() == _pendingCityName!.toLowerCase(),
        );
        if (match.isNotEmpty) matchedCityName = match.first.name;
      } else if (!_isEditMode) {
        final match = cities.where((c) => c.name == 'Jalandhar');
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
      SnackBar(
        content: Text('Could not load $what. Check your internet and try again.'),
        backgroundColor: Colors.red,
      ),
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

  // ================= PREFILL & HELPERS =================

  void _prefillForEdit(Map<String, dynamic> c) {
    final rawName = c['name']?.toString() ?? '';
    final titleMatch = RegExp(r'^(Mr\.|Mrs\.|Ms\.|Dr\.)\s+', caseSensitive: false)
        .firstMatch(rawName);
    if (titleMatch != null) {
      final matchedTitle = titleMatch.group(1)!;
      _selectedTitle = _titleOptions.firstWhere(
        (t) => t.toLowerCase() == matchedTitle.toLowerCase(),
        orElse: () => 'Mr.',
      );
      _customerNameController.text = rawName.substring(titleMatch.end).trim().toUpperCase();
    } else {
      _customerNameController.text = rawName.toUpperCase();
    }

    _parseAddressForEdit(c['address']?.toString() ?? '');

    _existingCustomerImageUrl = c['customerImage']?.toString();
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

    if (_showNewVisitForm) {
      _visitNumberController.text = (_visits.length + 1).toString();
    } else {
      _visitNumberController.text = c['numberOfVisit']?.toString() ?? '1';
    }

    if (!_showNewVisitForm && _visits.isNotEmpty) {
      final latest = _visits.last;
      _dateController.text = latest['visitDate']?.toString() ?? '';
      _purposeOfVisitController.text = latest['purposeOfVisit']?.toString() ?? '';
      _goldController.text = latest['gold']?.toString() ?? '';
      _diamondController.text = latest['diamond']?.toString() ?? '';
      _polkiController.text = latest['polki']?.toString() ?? '';
      _conclusion = _mapConclusionToUI(latest['conclusion']?.toString() ?? 'Pending');
      _requirementController.text = latest['requirement']?.toString() ?? '';
      _helperController.text = latest['helper']?.toString() ?? '';
      _existingGoldImageUrls = _parseImageUrls(latest['goldImages']);
      _existingDiamondImageUrls = _parseImageUrls(latest['diamondImages']);
      _existingPolkiImageUrls = _parseImageUrls(latest['polkiImages']);
    } else if (!_showNewVisitForm) {
      _clearNewVisitFields();
    }

    final reminder = c['reminder'];
    if (reminder != null && reminder is Map<String, dynamic>) {
      final status = reminder['status']?.toString() ?? 'pending';
      final rawDate = reminder['date']?.toString();
      if (status == 'pending' && rawDate != null && rawDate.isNotEmpty) {
        final parsedDate = DateTime.tryParse(rawDate);
        if (parsedDate != null) {
          final local = parsedDate.toLocal();
          _reminderController.text = _formatDate(local);
          _reminderTime = TimeOfDay(hour: local.hour, minute: local.minute);
          _reminderTimeController.text = _formatTime(_reminderTime!);
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
    final parts = rawAddress
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

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

    final parts = [street, city, state, country]
        .where((p) => p.trim().isNotEmpty)
        .toList();
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
    _existingGoldImageUrls = [];
    _existingDiamondImageUrls = [];
    _existingPolkiImageUrls = [];
    _reminderController.clear();
    _reminderTimeController.clear();
    _reminderMessageController.clear();
    _reminderTime = null;
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
    if (imageData is String && imageData.isNotEmpty) {
      return [imageData];
    }
    return [];
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
          if (response['data'] != null && response['data'] is List) {
            branchesData = response['data'] as List;
          } else if (response['branches'] != null && response['branches'] is List) {
            branchesData = response['branches'] as List;
          } else if (response['items'] != null && response['items'] is List) {
            branchesData = response['items'] as List;
          } else if (response['results'] != null && response['results'] is List) {
            branchesData = response['results'] as List;
          }
        } else if (response['data'] is List) {
          branchesData = response['data'] as List;
        }
        if (branchesData.isEmpty) {
          response.forEach((key, value) {
            if (value is List && value.isNotEmpty) {
              branchesData = value;
            }
          });
        }
      } else if (response is List) {
        branchesData = response;
      }
      setState(() {
        _branches = branchesData.map((item) {
          if (item is Map<String, dynamic>) return item;
          else if (item is String) return {'_id': item, 'name': item};
          else if (item is Map) {
            Map<String, dynamic> castMap = Map<String, dynamic>.from(item);
            return {
              '_id': castMap['_id']?.toString() ??
                  castMap['id']?.toString() ??
                  castMap['branchId']?.toString() ??
                  'unknown',
              'name': castMap['name']?.toString() ??
                  castMap['branchName']?.toString() ??
                  'Unknown Branch',
            };
          } else {
            return {'_id': 'unknown', 'name': 'Unknown Branch'};
          }
        }).toList().cast<Map<String, dynamic>>();
        _isLoadingBranches = false;
      });
    } catch (e) {
      setState(() { _branches = []; _isLoadingBranches = false; });
    }
  }

  // ---------- DATE / TIME HELPERS ----------
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _dateController.text = _formatDate(picked));
    }
  }

  Future<void> _selectReminderDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _reminderController.text = _formatDate(picked);
        if (_reminderTime == null) {
          _reminderTime = const TimeOfDay(hour: 10, minute: 0);
          _reminderTimeController.text = _formatTime(_reminderTime!);
        }
      });
    }
  }

  Future<void> _selectReminderTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime ?? const TimeOfDay(hour: 10, minute: 0),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _reminderTime = picked;
        _reminderTimeController.text = _formatTime(picked);
      });
    }
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  String _formatVisitDate(dynamic rawDate) {
    if (rawDate == null) return 'an unknown date';
    DateTime? date;
    if (rawDate is DateTime) {
      date = rawDate;
    } else {
      date = DateTime.tryParse(rawDate.toString());
    }
    if (date == null) return rawDate.toString();
    const monthsShort = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final local = date.toLocal();
    return '${local.day} ${monthsShort[local.month - 1]} ${local.year}';
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
        if (_isEditMode &&
            c['_id']?.toString() == widget.customerToEdit!['_id']?.toString()) {
          continue;
        }
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
        final visitDate = _formatVisitDate(match['visitDate']);
        final isPhoneDuplicate = phone.isNotEmpty &&
            (match['phone']?.toString().trim() ?? '') == phone;
        final isEmailDuplicate = email.isNotEmpty &&
            (match['email']?.toString().trim().toLowerCase() ?? '') == email;
        if (mounted) {
          setState(() {
            _duplicateMatch = match;
            if (isPhoneDuplicate) {
              _duplicateWarning =
                  'This phone number is already added in $branchDisplay branch on $visitDate. Tap to view this customer.';
            } else if (isEmailDuplicate) {
              _duplicateWarning =
                  'This email is already added in $branchDisplay branch on $visitDate. Tap to view this customer.';
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _duplicateWarning = null;
            _duplicateMatch = null;
          });
        }
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
    final branchId = branch is Map
        ? (branch['_id']?.toString() ?? branch['id']?.toString())
        : branch.toString();
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

  // ---------- IMAGE PICKING ----------
  Future<void> _showImageSourceOptions(String type) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'Add Photo',
                  style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primary),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(type, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.primary),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(type, ImageSource.gallery);
              },
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
        final XFile? photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
        if (photo != null) _addImageToList(type, File(photo.path));
      } else {
        final List<XFile> pickedImages = await _picker.pickMultiImage(imageQuality: 80);
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

  Future<void> _pickCustomerImage() async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'Customer Photo',
                  style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
              ),
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
                  setState(() {
                    _customerImageFile = null;
                    _existingCustomerImageUrl = null;
                  });
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
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
      List<File> images;
      if (type == 'gold') images = _goldImages;
      else if (type == 'diamond') images = _diamondImages;
      else images = _polkiImages;
      if (index >= 0 && index < images.length) {
        images.removeAt(index);
      }
    });
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
      if (reminderDateTime != null &&
          reminderMessage != null &&
          reminderMessage.isNotEmpty) {
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

  // ---------- OPEN EXISTING (DUPLICATE) CUSTOMER ----------
  void _openDuplicateCustomer() {
    if (_duplicateMatch == null) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AddCustomerScreen(
          employees: widget.employees,
          customers: widget.customers,
          customerToEdit: _duplicateMatch,
        ),
      ),
    );
  }

  // ---------- EDIT AN EXISTING VISIT (from Visit History) ----------
  Future<void> _openEditVisit(Map<String, dynamic> visit, int index) async {
    final rawVisitNumber = visit['visitNumber'];
    final visitNumber = rawVisitNumber is int
        ? rawVisitNumber
        : int.tryParse(rawVisitNumber?.toString() ?? '') ?? (index + 1);

    final updatedCustomer = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => EditVisitScreen(
          customerId: widget.customerToEdit!['_id'].toString(),
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
        const SnackBar(
          content: Text('Visit updated successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  // ---------- MARK REQUIREMENT AS FULFILLED ----------
  Future<void> _confirmFulfillRequirement(Map<String, dynamic> visit, int index) async {
    final visitNumber = index + 1;
    final requirementText = visit['requirement']?.toString() ?? '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark Requirement Available'),
        content: Text(
          'Mark "$requirementText" as available in stock?\n\nThis will move it out of the pending requirements list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mark Available', style: TextStyle(color: AppColors.success)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final customerId = widget.customerToEdit!['_id'].toString();
      final response = await ApiService().fulfillRequirement(customerId, visitNumber);

      if (response['success'] == true) {
        setState(() {
          _visits[index]['requirementStatus'] = 'fulfilled';
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Requirement marked as available. Contact the customer!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${response['message'] ?? 'Failed to update requirement'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ---------- DELETE AN EXISTING VISIT (from Visit History) ----------
  Future<void> _confirmDeleteVisit(Map<String, dynamic> visit, int index) async {
    final visitNumber = index + 1;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Visit'),
        content: Text(
          'Are you sure you want to delete Visit #$visitNumber? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final customerId = widget.customerToEdit!['_id'].toString();
      final response = await ApiService().deleteVisit(customerId, visitNumber);

      if (response['success'] == true) {
        setState(() {
          _visits.removeAt(index);
          _visitExpanded = List<bool>.filled(_visits.length, false);
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Visit deleted successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${response['message'] ?? 'Failed to delete visit'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ---------- MAIN SAVE ----------
  Future<void> _addCustomer() async {
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

    if (_selectedCountry == null || _selectedState == null || _resolvedCityName().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select city, state and country'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_selectedEmployee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select who attended'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_selectedBranch == null && !_isEditMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select branch'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_isReferenceCustomer && _selectedReferredBy == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select the referring customer, or switch to Write Note'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
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
          reminderDateStr = reminderDateTime.toIso8601String();
          reminderMessageStr = reminderMessageText;
        }
      }

      String? finalProfession;
      if (_selectedProfession != null) {
        finalProfession = _selectedProfession == 'Others'
            ? _customProfessionController.text.trim()
            : _selectedProfession;
      }
      String? finalCommunity;
      if (_selectedCommunity != null) {
        finalCommunity = _selectedCommunity == 'Others'
            ? _customCommunityController.text.trim()
            : _selectedCommunity;
      }

      Map<String, dynamic> response;
      String? customerId;

      if (_isAddingVisit && _isEditMode) {
        customerId = widget.customerToEdit!['_id'].toString();
        final visitData = <String, dynamic>{
          'purposeOfVisit': _purposeOfVisitController.text.trim(),
          'gold': _goldController.text.trim(),
          'diamond': _diamondController.text.trim(),
          'polki': _polkiController.text.trim(),
          'requirement': _requirementController.text.trim(),
          'conclusion': _mapConclusionToServer(_conclusion),
          'whoAttend': _selectedEmployee,
          'helper': _helperController.text.trim(),
          'visitDate': _dateController.text.trim(),
        };
        response = await apiService.addVisitToCustomer(
          customerId,
          visitData,
          _goldImages,
          _diamondImages,
          _polkiImages,
        );
      } else if (_isEditMode) {
        customerId = widget.customerToEdit!['_id'].toString();
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
        if (email.isNotEmpty) {
          customerData['email'] = email;
        }
        // Requirement is NOT included here because it's visit-specific.
        if (reminderDateStr != null && reminderDateStr.isNotEmpty) {
          customerData['reminderDate'] = reminderDateStr;
        }
        if (reminderMessageStr != null && reminderMessageStr.isNotEmpty) {
          customerData['reminderMessage'] = reminderMessageStr;
        }
        if (_birthdayDay != null && _birthdayMonth != null) {
          customerData['birthday'] =
              '${_birthdayDay!.toString().padLeft(2, '0')}-${_birthdayMonth!.toString().padLeft(2, '0')}';
        }
        if (_anniversaryDay != null && _anniversaryMonth != null) {
          customerData['anniversary'] =
              '${_anniversaryDay!.toString().padLeft(2, '0')}-${_anniversaryMonth!.toString().padLeft(2, '0')}';
        }
        if (finalProfession != null && finalProfession.isNotEmpty) {
          customerData['profession'] = finalProfession;
        }
        if (finalCommunity != null && finalCommunity.isNotEmpty) {
          customerData['community'] = finalCommunity;
        }
        if (_isReferenceCustomer && _selectedReferredBy != null) {
          customerData['referredBy'] = _selectedReferredBy;
        }
        if (!customerData.containsKey('reminderDate') || customerData['reminderDate'] == null) {
          customerData['clearReminder'] = true;
        }

        response = await apiService.updateCustomer(
          widget.customerToEdit!['_id'].toString(),
          customerData,
          customerImage: _customerImageFile,
        );
      } else {
        // New customer – includes first visit
        final customerData = <String, dynamic>{
          'name': _buildFullName(),
          'phone': _phoneController.text.trim(),
          'address': _buildFullAddress(),
          'purposeOfVisit': _purposeOfVisitController.text.trim(),
          'numberOfVisit': _visitNumberController.text.trim(),
          'branch': _selectedBranch,
          'gold': _goldController.text.trim(),
          'diamond': _diamondController.text.trim(),
          'polki': _polkiController.text.trim(),
          'conclusion': _mapConclusionToServer(_conclusion),
          'requirement': _requirementController.text.trim(),
          'assignedTo': _selectedEmployee,
          'whoAttend': _selectedEmployee,
          'helper': _helperController.text.trim(),
          'referenceNote': _isReferenceCustomer ? '' : _referenceNoteController.text.trim(),
          'visitDate': _dateController.text.trim(),
        };

        final email = _emailController.text.trim();
        if (email.isNotEmpty) {
          customerData['email'] = email;
        }

        if (reminderDateStr != null && reminderDateStr.isNotEmpty) {
          customerData['reminderDate'] = reminderDateStr;
        }
        if (reminderMessageStr != null && reminderMessageStr.isNotEmpty) {
          customerData['reminderMessage'] = reminderMessageStr;
        }
        if (_birthdayDay != null && _birthdayMonth != null) {
          customerData['birthday'] =
              '${_birthdayDay!.toString().padLeft(2, '0')}-${_birthdayMonth!.toString().padLeft(2, '0')}';
        }
        if (_anniversaryDay != null && _anniversaryMonth != null) {
          customerData['anniversary'] =
              '${_anniversaryDay!.toString().padLeft(2, '0')}-${_anniversaryMonth!.toString().padLeft(2, '0')}';
        }
        if (finalProfession != null && finalProfession.isNotEmpty) {
          customerData['profession'] = finalProfession;
        }
        if (finalCommunity != null && finalCommunity.isNotEmpty) {
          customerData['community'] = finalCommunity;
        }
        if (_isReferenceCustomer && _selectedReferredBy != null) {
          customerData['referredBy'] = _selectedReferredBy;
        }

        response = await apiService.createCustomerWithImages(
          customerData,
          _goldImages,
          _diamondImages,
          _polkiImages,
          customerImage: _customerImageFile,
        );

        if (response['success'] == true && response['data'] != null) {
          customerId = response['data']['_id']?.toString();
        }
      }

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

        String successMessage;
        if (_isAddingVisit) {
          successMessage = 'Visit #${_visitNumberController.text} added successfully!';
        } else if (_isEditMode) {
          successMessage = 'Customer updated successfully!';
        } else {
          successMessage = 'Customer added successfully!';
        }

        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(successMessage),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 2),
            ),
          );
        }

        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) Navigator.pop(context, true);
        });
      } else {
        final errorMessage = response['message'] ?? 'Failed to save';
        if (mounted) {
          setState(() => _isLoading = false);
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
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
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
    _duplicateCheckDebounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  // ================= BUILD =================
  @override
  Widget build(BuildContext context) {
    String title;
    if (_isAddingVisit) {
      title = 'Add New Visit';
    } else if (_isEditMode) {
      title = 'Edit Customer';
    } else {
      title = 'Add Customer';
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _addCustomer,
            child: Text(
              _isLoading ? 'Saving...' : 'Save',
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary),
            ),
          ),
        ],
      ),
      floatingActionButton: _isEditMode && !_isAddingVisit
          ? FloatingActionButton(
              onPressed: () {
                setState(() {
                  _showNewVisitForm = true;
                  _clearNewVisitFields();
                  _visitNumberController.text = (_visits.length + 1).toString();
                });
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });
              },
              child: const Icon(Icons.add),
            )
          : null,
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text(
                    _isAddingVisit ? 'Adding visit...' : _isEditMode ? 'Updating customer...' : 'Adding customer...',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('Personal Information'),
                    const SizedBox(height: 16),
                    Center(child: _buildCustomerImagePicker()),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        SizedBox(
                          width: 108,
                          child: _buildDropdownField<String>(
                            label: 'Title',
                            icon: Icons.badge_outlined,
                            value: _selectedTitle,
                            items: _titleOptions
                                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                                .toList(),
                            onChanged: (v) => setState(() => _selectedTitle = v ?? 'Mr.'),
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
                    const Text(
                      'Phone Number *',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CountryCodePicker(
                            onChanged: (country) {
                              setState(() => _countryCode = country.dialCode ?? '+91');
                            },
                            initialSelection: 'IN',
                            favorite: const ['+91', 'IN'],
                            showCountryOnly: false,
                            showOnlyCountryWhenClosed: false,
                            alignLeft: false,
                            padding: EdgeInsets.zero,
                            flagWidth: 24,
                            textStyle: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Container(height: 28, width: 1, color: AppColors.border),
                          Expanded(
                            child: TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
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
                          if (!emailRegex.hasMatch(value.trim())) {
                            return 'Enter a valid email';
                          }
                        }
                        return null;
                      },
                    ),
                    if (_duplicateWarning != null) ...[
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _duplicateMatch != null ? _openDuplicateCustomer : null,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _duplicateWarning!,
                                  style: const TextStyle(color: Colors.deepOrange, fontSize: 13),
                                ),
                              ),
                              if (_duplicateMatch != null)
                                const Icon(Icons.chevron_right, color: Colors.deepOrange, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _buildAddressSection(),
                    const SizedBox(height: 14),
                    _buildDropdownField<String>(
                      label: 'Branch *',
                      icon: Icons.store,
                      loading: _isLoadingBranches,
                      hint: _branches.isEmpty && !_isLoadingBranches ? 'No branches available' : 'Select Branch',
                      value: _selectedBranch,
                      items: _branches.map((branch) {
                        final branchId = branch['_id']?.toString() ??
                            branch['id']?.toString() ??
                            branch['branchId']?.toString();
                        final displayName = '${branch['name']} (${branch['city']})';
                        return DropdownMenuItem<String>(value: branchId, child: Text(displayName));
                      }).toList(),
                      onChanged: (value) => setState(() => _selectedBranch = value),
                      validator: (value) {
                        if (_branches.isEmpty) return 'No branches available. Please contact admin.';
                        if (value == null) return 'Please select branch';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    CrmTextField(
                      label: 'Number of Visit',
                      hint: 'How many times visited',
                      prefixIcon: Icons.timeline,
                      controller: _visitNumberController,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 24),

                    // Visit History (only in edit mode)
                    if (_isEditMode && _visits.isNotEmpty) ...[
                      _buildSectionHeader('Visit History (${_visits.length} visits)'),
                      const SizedBox(height: 4),
                      const Text(
                        'Tap the pencil icon on any visit to edit its details, or the trash icon to delete it.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      ..._visits.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final visit = entry.value;
                        return _buildVisitCard(visit, idx);
                      }).toList(),
                      const SizedBox(height: 24),
                    ],

                    // --- EDIT CUSTOMER (without adding visit) ---
                    // Requirement field is NOT shown here.
                    if (_isEditMode && !_isAddingVisit) ...[
                      _buildSectionHeader('Staff Information'),
                      const SizedBox(height: 8),
                      _buildDropdownField<String>(
                        label: 'Assigned To *',
                        icon: Icons.person,
                        value: _selectedEmployee,
                        items: widget.employees.map((employee) {
                          return DropdownMenuItem<String>(
                            value: employee['_id'].toString(),
                            child: Text(employee['name'] ?? 'Unknown'),
                          );
                        }).toList(),
                        onChanged: (value) => setState(() => _selectedEmployee = value),
                        validator: (value) => value == null ? 'Please select an employee' : null,
                      ),
                      const SizedBox(height: 24),
                    ],

                    // --- ADD NEW VISIT (to existing customer) ---
                    if (_isAddingVisit) ...[
                      _buildSectionHeader('New Visit #${_visits.length + 1}'),
                      const SizedBox(height: 16),
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
                      const SizedBox(height: 16),
                      _buildSectionHeader('Jewelry Details'),
                      const SizedBox(height: 8),
                      CrmTextField(
                        label: 'Gold Details',
                        hint: 'Gold weight, purity, etc.',
                        prefixIcon: Icons.workspace_premium,
                        controller: _goldController,
                      ),
                      const SizedBox(height: 8),
                      _buildImageUploadSection('Gold Images', _goldImages, const [], 'gold'),
                      const SizedBox(height: 8),
                      CrmTextField(
                        label: 'Diamond Details',
                        hint: 'Diamond carat, clarity, etc.',
                        prefixIcon: Icons.diamond,
                        controller: _diamondController,
                      ),
                      const SizedBox(height: 8),
                      _buildImageUploadSection('Diamond Images', _diamondImages, const [], 'diamond'),
                      const SizedBox(height: 8),
                      CrmTextField(
                        label: 'Polki Details',
                        hint: 'Polki weight, etc.',
                        prefixIcon: Icons.star_outline,
                        controller: _polkiController,
                      ),
                      const SizedBox(height: 8),
                      _buildImageUploadSection('Polki Images', _polkiImages, const [], 'polki'),
                      const SizedBox(height: 16),
                      _buildSectionHeader('Conclusion'),
                      const SizedBox(height: 8),
                      _buildDropdownField<String>(
                        label: 'Conclusion',
                        icon: Icons.flag,
                        value: _conclusion,
                        items: const [
                          DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                          DropdownMenuItem(value: 'Sold', child: Text('Sold')),
                          DropdownMenuItem(value: 'Shortlisted', child: Text('Shortlisted')),
                          DropdownMenuItem(value: 'Just See', child: Text('Just See')),
                          DropdownMenuItem(value: 'On Order', child: Text('On Order')),
                          DropdownMenuItem(value: 'On Approval', child: Text('On Approval')),
                        ],
                        onChanged: (value) => setState(() => _conclusion = value!),
                      ),
                      const SizedBox(height: 16),
                      // Requirement field for the new visit
                      _buildSectionHeader('Requirement'),
                      const SizedBox(height: 8),
                      CrmTextField(
                        label: 'Requirement',
                        hint: 'Specific requirements',
                        prefixIcon: Icons.checklist,
                        controller: _requirementController,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      _buildSectionHeader('Staff Information'),
                      const SizedBox(height: 8),
                      _buildDropdownField<String>(
                        label: 'Who Attended *',
                        icon: Icons.person,
                        value: _selectedEmployee,
                        items: widget.employees.map((employee) {
                          return DropdownMenuItem<String>(
                            value: employee['_id'].toString(),
                            child: Text(employee['name'] ?? 'Unknown'),
                          );
                        }).toList(),
                        onChanged: (value) => setState(() => _selectedEmployee = value),
                        validator: (value) => value == null ? 'Please select who attended' : null,
                      ),
                      const SizedBox(height: 12),
                      CrmTextField(
                        label: 'Helper',
                        hint: 'Helper name',
                        prefixIcon: Icons.handshake,
                        controller: _helperController,
                      ),
                      const SizedBox(height: 16),
                      _buildSectionHeader('Reminder (optional)'),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _selectReminderDate(context),
                        child: AbsorbPointer(
                          child: CrmTextField(
                            label: 'Reminder Date',
                            hint: 'Select reminder date',
                            prefixIcon: Icons.alarm,
                            controller: _reminderController,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _selectReminderTime(context),
                        child: AbsorbPointer(
                          child: CrmTextField(
                            label: 'Reminder Time',
                            hint: 'Select reminder time',
                            prefixIcon: Icons.access_time,
                            controller: _reminderTimeController,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      CrmTextField(
                        label: 'Reminder Message',
                        hint: 'e.g. Customer wants order confirmation',
                        prefixIcon: Icons.message,
                        controller: _reminderMessageController,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _showNewVisitForm = false;
                                  _clearNewVisitFields();
                                  if (_visits.isNotEmpty) {
                                    final latest = _visits.last;
                                    _dateController.text = latest['visitDate']?.toString() ?? '';
                                    _purposeOfVisitController.text = latest['purposeOfVisit']?.toString() ?? '';
                                    _goldController.text = latest['gold']?.toString() ?? '';
                                    _diamondController.text = latest['diamond']?.toString() ?? '';
                                    _polkiController.text = latest['polki']?.toString() ?? '';
                                    _conclusion = _mapConclusionToUI(latest['conclusion']?.toString() ?? 'Pending');
                                    _requirementController.text = latest['requirement']?.toString() ?? '';
                                    _helperController.text = latest['helper']?.toString() ?? '';
                                    _existingGoldImageUrls = _parseImageUrls(latest['goldImages']);
                                    _existingDiamondImageUrls = _parseImageUrls(latest['diamondImages']);
                                    _existingPolkiImageUrls = _parseImageUrls(latest['polkiImages']);
                                  } else {
                                    _clearNewVisitFields();
                                  }
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: const BorderSide(color: Colors.grey),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _addCustomer,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('Add Visit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // --- EDIT CUSTOMER (additional info) ---
                    if (!_isAddingVisit && _isEditMode) ...[
                      _buildSectionHeader('Additional Information'),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () => _selectReminderDate(context),
                        child: AbsorbPointer(
                          child: CrmTextField(
                            label: 'Reminder Date',
                            hint: 'Select reminder date',
                            prefixIcon: Icons.alarm,
                            controller: _reminderController,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => _selectReminderTime(context),
                        child: AbsorbPointer(
                          child: CrmTextField(
                            label: 'Reminder Time',
                            hint: 'Select reminder time',
                            prefixIcon: Icons.access_time,
                            controller: _reminderTimeController,
                          ),
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
                      const SizedBox(height: 16),
                      _buildBirthdayField(),
                      const SizedBox(height: 16),
                      _buildAnniversaryField(),
                      const SizedBox(height: 16),
                      _buildProfessionField(),
                      const SizedBox(height: 16),
                      _buildCommunityField(),
                      const SizedBox(height: 12),
                      _buildReferenceSection(),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _addCustomer,
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
                              : const Text('Update Customer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // --- ADD NEW CUSTOMER (includes first visit) ---
                    if (!_isEditMode) ...[
                      _buildSectionHeader('Visit Details'),
                      const SizedBox(height: 16),
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
                      const SizedBox(height: 16),
                      _buildSectionHeader('Jewelry Details'),
                      const SizedBox(height: 8),
                      CrmTextField(
                        label: 'Gold Details',
                        hint: 'Gold weight, purity, etc.',
                        prefixIcon: Icons.workspace_premium,
                        controller: _goldController,
                      ),
                      const SizedBox(height: 8),
                      _buildImageUploadSection('Gold Images', _goldImages, const [], 'gold'),
                      const SizedBox(height: 8),
                      CrmTextField(
                        label: 'Diamond Details',
                        hint: 'Diamond carat, clarity, etc.',
                        prefixIcon: Icons.diamond,
                        controller: _diamondController,
                      ),
                      const SizedBox(height: 8),
                      _buildImageUploadSection('Diamond Images', _diamondImages, const [], 'diamond'),
                      const SizedBox(height: 8),
                      CrmTextField(
                        label: 'Polki Details',
                        hint: 'Polki weight, etc.',
                        prefixIcon: Icons.star_outline,
                        controller: _polkiController,
                      ),
                      const SizedBox(height: 8),
                      _buildImageUploadSection('Polki Images', _polkiImages, const [], 'polki'),
                      const SizedBox(height: 16),
                      _buildSectionHeader('Conclusion'),
                      const SizedBox(height: 8),
                      _buildDropdownField<String>(
                        label: 'Conclusion',
                        icon: Icons.flag,
                        value: _conclusion,
                        items: const [
                          DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                          DropdownMenuItem(value: 'Sold', child: Text('Sold')),
                          DropdownMenuItem(value: 'Shortlisted', child: Text('Shortlisted')),
                          DropdownMenuItem(value: 'Just See', child: Text('Just See')),
                          DropdownMenuItem(value: 'On Order', child: Text('On Order')),
                          DropdownMenuItem(value: 'On Approval', child: Text('On Approval')),
                        ],
                        onChanged: (value) => setState(() => _conclusion = value!),
                      ),
                      const SizedBox(height: 16),
                      // Requirement field for the first visit
                      _buildSectionHeader('Requirement'),
                      const SizedBox(height: 8),
                      CrmTextField(
                        label: 'Requirement',
                        hint: 'Specific requirements',
                        prefixIcon: Icons.checklist,
                        controller: _requirementController,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      _buildSectionHeader('Staff Information'),
                      const SizedBox(height: 8),
                      _buildDropdownField<String>(
                        label: 'Who Attended *',
                        icon: Icons.person,
                        value: _selectedEmployee,
                        items: widget.employees.map((employee) {
                          return DropdownMenuItem<String>(
                            value: employee['_id'].toString(),
                            child: Text(employee['name'] ?? 'Unknown'),
                          );
                        }).toList(),
                        onChanged: (value) => setState(() => _selectedEmployee = value),
                        validator: (value) => value == null ? 'Please select who attended' : null,
                      ),
                      const SizedBox(height: 12),
                      CrmTextField(
                        label: 'Helper',
                        hint: 'Helper name',
                        prefixIcon: Icons.handshake,
                        controller: _helperController,
                      ),
                      const SizedBox(height: 16),
                      _buildSectionHeader('Additional Information'),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () => _selectReminderDate(context),
                        child: AbsorbPointer(
                          child: CrmTextField(
                            label: 'Reminder Date',
                            hint: 'Select reminder date',
                            prefixIcon: Icons.alarm,
                            controller: _reminderController,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => _selectReminderTime(context),
                        child: AbsorbPointer(
                          child: CrmTextField(
                            label: 'Reminder Time',
                            hint: 'Select reminder time',
                            prefixIcon: Icons.access_time,
                            controller: _reminderTimeController,
                          ),
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
                      const SizedBox(height: 16),
                      _buildBirthdayField(),
                      const SizedBox(height: 16),
                      _buildAnniversaryField(),
                      const SizedBox(height: 16),
                      _buildProfessionField(),
                      const SizedBox(height: 16),
                      _buildCommunityField(),
                      const SizedBox(height: 12),
                      _buildReferenceSection(),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _addCustomer,
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
                              : const Text('Add Customer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  // ================= WIDGET HELPERS =================

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
    );
  }

  Widget _buildCustomerImagePicker() {
    ImageProvider? imageProvider;
    if (_customerImageFile != null) {
      imageProvider = FileImage(_customerImageFile!);
    } else if (_existingCustomerImageUrl != null && _existingCustomerImageUrl!.isNotEmpty) {
      imageProvider = NetworkImage(ApiService.getImageUrl(_existingCustomerImageUrl!));
    }

    return GestureDetector(
      onTap: _pickCustomerImage,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: AppColors.border,
            backgroundImage: imageProvider,
            child: imageProvider == null
                ? const Icon(Icons.person, size: 48, color: AppColors.textSecondary)
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // Reusable dropdown field
  Widget _buildDropdownField<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    String? hint,
    bool loading = false,
    String? Function(T?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        DropdownButtonHideUnderline(
          child: DropdownButtonFormField<T>(
            value: value,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.textSecondary),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: loading ? const Color(0xFFF1F1F3) : Colors.white,
              hintText: loading ? 'Loading...' : hint,
              hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
              prefixIcon: Icon(icon, size: 20, color: AppColors.textSecondary),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.red),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.red, width: 1.4),
              ),
            ),
            items: loading ? const [] : items,
            onChanged: loading ? null : onChanged,
            validator: validator,
          ),
        ),
      ],
    );
  }

  Widget _buildBirthdayField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Birthday (optional)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildDropdownField<int>(
                label: 'Day',
                icon: Icons.today,
                value: _birthdayDay,
                items: List.generate(31, (i) => i + 1)
                    .map((d) => DropdownMenuItem(value: d, child: Text('$d')))
                    .toList(),
                onChanged: (v) => setState(() => _birthdayDay = v),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: _buildDropdownField<int>(
                label: 'Month',
                icon: Icons.calendar_month,
                value: _birthdayMonth,
                items: List.generate(12, (i) => i + 1)
                    .map((m) => DropdownMenuItem(value: m, child: Text(_months[m - 1])))
                    .toList(),
                onChanged: (v) => setState(() => _birthdayMonth = v),
              ),
            ),
            if (_birthdayDay != null || _birthdayMonth != null) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                tooltip: 'Clear birthday',
                onPressed: () => setState(() {
                  _birthdayDay = null;
                  _birthdayMonth = null;
                }),
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
        const Text('Anniversary (optional)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildDropdownField<int>(
                label: 'Day',
                icon: Icons.today,
                value: _anniversaryDay,
                items: List.generate(31, (i) => i + 1)
                    .map((d) => DropdownMenuItem(value: d, child: Text('$d')))
                    .toList(),
                onChanged: (v) => setState(() => _anniversaryDay = v),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: _buildDropdownField<int>(
                label: 'Month',
                icon: Icons.calendar_month,
                value: _anniversaryMonth,
                items: List.generate(12, (i) => i + 1)
                    .map((m) => DropdownMenuItem(value: m, child: Text(_months[m - 1])))
                    .toList(),
                onChanged: (v) => setState(() => _anniversaryMonth = v),
              ),
            ),
            if (_anniversaryDay != null || _anniversaryMonth != null) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                tooltip: 'Clear anniversary',
                onPressed: () => setState(() {
                  _anniversaryDay = null;
                  _anniversaryMonth = null;
                }),
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
        _buildDropdownField<String>(
          label: 'Profession (optional)',
          icon: Icons.work,
          hint: 'Select Profession',
          value: _selectedProfession,
          items: _professionOptionsList.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
          onChanged: (v) => setState(() => _selectedProfession = v),
        ),
        if (_selectedProfession == 'Others') ...[
          const SizedBox(height: 8),
          CrmTextField(
            label: 'Specify Profession',
            hint: 'Type profession',
            prefixIcon: Icons.edit,
            controller: _customProfessionController,
          ),
        ],
      ],
    );
  }

  Widget _buildCommunityField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDropdownField<String>(
          label: 'Community (optional)',
          icon: Icons.groups,
          hint: 'Select Community',
          value: _selectedCommunity,
          items: _communityOptionsList.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
          onChanged: (v) => setState(() => _selectedCommunity = v),
        ),
        if (_selectedCommunity == 'Others') ...[
          const SizedBox(height: 8),
          CrmTextField(
            label: 'Specify Community',
            hint: 'Type community',
            prefixIcon: Icons.edit,
            controller: _customCommunityController,
          ),
        ],
      ],
    );
  }

  Widget _buildAddressSection() {
    final preview = _buildFullAddress();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.location_on_outlined, size: 18, color: AppColors.primary),
              SizedBox(width: 6),
              Text('Address', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 4),
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
          _buildDropdownField<String>(
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
          _buildDropdownField<String>(
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
          _buildDropdownField<String>(
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
              if (_cityNotInList) {
                return _customCityController.text.trim().isEmpty ? 'Type the city name' : null;
              }
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
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Will be saved as: ${preview.isEmpty ? '—' : preview}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferenceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Reference', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Text('Write Note'),
                selected: !_isReferenceCustomer,
                selectedColor: AppColors.primary.withOpacity(0.15),
                onSelected: (_) => setState(() {
                  _isReferenceCustomer = false;
                  _selectedReferredBy = null;
                }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ChoiceChip(
                label: const Text('Select Customer'),
                selected: _isReferenceCustomer,
                selectedColor: AppColors.primary.withOpacity(0.15),
                onSelected: (_) => setState(() {
                  _isReferenceCustomer = true;
                  _referenceNoteController.clear();
                }),
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
          _buildDropdownField<String>(
            label: 'Referred By',
            icon: Icons.family_restroom,
            hint: 'Select the customer who referred them',
            value: _selectedReferredBy,
            items: widget.customers.map((customer) {
              return DropdownMenuItem<String>(
                value: customer['_id'].toString(),
                child: Text(customer['name'] ?? 'Unknown'),
              );
            }).toList(),
            onChanged: (value) => setState(() => _selectedReferredBy = value),
            validator: (value) {
              if (_isReferenceCustomer && value == null) {
                return 'Please select a referring customer';
              }
              return null;
            },
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
    final conclusionUI = _mapConclusionToUI(conclusionServer);
    final requirement = visit['requirement']?.toString() ?? '';
    final requirementStatus = visit['requirementStatus']?.toString() ?? 'none';
    final helper = visit['helper']?.toString() ?? '';
    final whoAttendName = _getEmployeeName(visit['whoAttend']);
    final goldImages = _parseImageUrls(visit['goldImages']);
    final diamondImages = _parseImageUrls(visit['diamondImages']);
    final polkiImages = _parseImageUrls(visit['polkiImages']);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ExpansionTile(
        initiallyExpanded: _visitExpanded[index],
        onExpansionChanged: (expanded) {
          setState(() {
            _visitExpanded[index] = expanded;
          });
        },
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
              child: Text('#$visitNumber',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(purpose, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15), overflow: TextOverflow.ellipsis),
                  Text(date.isNotEmpty ? _formatVisitDate(date) : 'No date',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: conclusionUI == 'Sold' ? AppColors.success : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                conclusionUI,
                style: TextStyle(
                  color: conclusionUI == 'Sold' ? Colors.white : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 20, color: AppColors.primary),
              tooltip: 'Edit this visit',
              onPressed: () => _openEditVisit(visit, index),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
              tooltip: 'Delete this visit',
              onPressed: () => _confirmDeleteVisit(visit, index),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Date', date.isNotEmpty ? _formatVisitDate(date) : 'Not set'),
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
                    TextButton.icon(
                      onPressed: () => _openEditVisit(visit, index),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit'),
                    ),
                    TextButton.icon(
                      onPressed: () => _confirmDeleteVisit(visit, index),
                      icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                      label: const Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
          ),
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
        const SizedBox(
          width: 100,
          child: Text('Requirement:', style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Requirement text + status chip inline
              Row(
                children: [
                  Expanded(
                    child: Text(
                      requirement,
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Status Chip
                  Chip(
                    label: Text(
                      isFulfilled ? 'Available' : 'Pending',
                      style: TextStyle(
                        color: isFulfilled ? Colors.white : Colors.orange[800],
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                    backgroundColor: isFulfilled ? AppColors.success : Colors.orange.withOpacity(0.2),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
              // "Mark Available" link for pending requirements
              if (isPending) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () => _confirmFulfillRequirement(visit, index),
                      child: const Text(
                        'Mark Available',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                          decoration: TextDecoration.underline,
                        ),
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
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      ApiService.getImageUrl(imageUrls[i]),
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 40),
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

  Widget _buildImageUploadSection(
    String label,
    List<File> images,
    List<String> imageUrls,
    String type,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        if (imageUrls.isNotEmpty) ...[
          const Text('Previously uploaded:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Container(
            height: 90,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: imageUrls.length,
              itemBuilder: (context, index) {
                return Container(
                  width: 90,
                  height: 90,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      ApiService.getImageUrl(imageUrls[index]),
                      fit: BoxFit.cover,
                      width: 90,
                      height: 90,
                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 36),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        if (images.isNotEmpty)
          Container(
            height: 100,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(images[index], fit: BoxFit.cover, width: 100, height: 100),
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 10,
                      child: GestureDetector(
                        onTap: () => _removeImage(type, index),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        InkWell(
          onTap: () => _showImageSourceOptions(type),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border, width: 1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Icon(Icons.add_a_photo, size: 30, color: AppColors.primary.withOpacity(0.6)),
                const SizedBox(height: 4),
                Text(
                  images.isNotEmpty ? '${images.length} image(s) - Tap to add more' : 'Add $label (Camera or Gallery)',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // Constants
  static const List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  static const List<String> _titleOptions = ['Mr.', 'Mrs.', 'Ms.', 'Dr.'];

  List<String> _professionOptionsList = [];
  List<String> _communityOptionsList = [];

  static const List<String> _defaultProfessionOptions = [
    'Doctor', 'Business Man', 'Teacher', 'Police', 'Others'
  ];
  static const List<String> _defaultCommunityOptions = [
    'HNI/IMP', 'Very Good', 'Good', 'Medium', 'Small'
  ];
}