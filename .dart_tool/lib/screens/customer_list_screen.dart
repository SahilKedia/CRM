import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'add_customer_screen.dart';
import 'dashboard_screen.dart';           // Admin dashboard
import 'employee_dashboard_screen.dart';  // Employee dashboard

class CustomerListScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final List<Map<String, dynamic>> employees;

  const CustomerListScreen({
    Key? key,
    required this.user,
    required this.employees,
  }) : super(key: key);

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  List<Map<String, dynamic>> _allCustomers = [];
  List<Map<String, dynamic>> _filteredCustomers = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  // Filter state
  String? _selectedProfession;
  String? _selectedCommunity;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ---------- Branch filtering ----------
  String? get _adminBranchId {
    final branch = widget.user['branch'];
    if (branch == null) return null;
    if (branch is Map) return branch['_id']?.toString();
    return branch.toString();
  }

  String? _getCustomerBranchId(Map<String, dynamic> customer) {
    final branch = customer['branch'];
    if (branch == null) return null;
    if (branch is Map) return branch['_id']?.toString();
    return branch.toString();
  }

  // ---------- Profession / community helpers ----------
  String? _getProfession(Map<String, dynamic> c) {
    final p = c['profession'];
    if (p == null || p.toString().trim().isEmpty) return null;
    return p.toString().trim();
  }

  String? _getCommunity(Map<String, dynamic> c) {
    final comm = c['community'];
    if (comm == null || comm.toString().trim().isEmpty) return null;
    return comm.toString().trim();
  }

  List<String> get _professionOptions {
    final adminBranch = _adminBranchId;
    final base = adminBranch == null
        ? _allCustomers
        : _allCustomers.where((c) => _getCustomerBranchId(c) == adminBranch);
    final set = <String>{};
    for (final c in base) {
      final p = _getProfession(c);
      if (p != null) set.add(p);
    }
    final list = set.toList()..sort();
    return list;
  }

  List<String> get _communityOptions {
    final adminBranch = _adminBranchId;
    final base = adminBranch == null
        ? _allCustomers
        : _allCustomers.where((c) => _getCustomerBranchId(c) == adminBranch);
    final set = <String>{};
    for (final c in base) {
      final comm = _getCommunity(c);
      if (comm != null) set.add(comm);
    }
    final list = set.toList()..sort();
    return list;
  }

  // ---------- Load customers ----------
  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService().getCustomers();
      if (response['success'] == true) {
        final data = response['customers'] ?? response['data'] ?? [];
        final customers = List<Map<String, dynamic>>.from(data);

        setState(() {
          _allCustomers = customers;
          _isLoading = false;
        });
        _applyFilters();
      } else {
        setState(() {
          _allCustomers = [];
          _filteredCustomers = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _allCustomers = [];
        _filteredCustomers = [];
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading customers: $e')),
        );
      }
    }
  }

  // ---------- Combined filter (branch + search + profession + community) ----------
  void _applyFilters() {
    final adminBranch = _adminBranchId;
    final query = _searchController.text.toLowerCase().trim();

    final result = _allCustomers.where((c) {
      if (adminBranch != null && _getCustomerBranchId(c) != adminBranch) {
        return false;
      }

      if (_selectedProfession != null &&
          _getProfession(c) != _selectedProfession) {
        return false;
      }

      if (_selectedCommunity != null &&
          _getCommunity(c) != _selectedCommunity) {
        return false;
      }

      if (query.isNotEmpty) {
        final name = (c['name'] ?? '').toString().toLowerCase();
        final phone = (c['phone'] ?? '').toString().toLowerCase();
        final profession = (c['profession'] ?? '').toString().toLowerCase();
        if (!name.contains(query) &&
            !phone.contains(query) &&
            !profession.contains(query)) {
          return false;
        }
      }

      return true;
    }).toList();

    setState(() => _filteredCustomers = result);
  }

  // ---------- Search ----------
  void _onSearchChanged(String query) {
    _applyFilters();
  }

  void _clearSearch() {
    _searchController.clear();
    _applyFilters();
  }

  // ---------- Filter bottom sheet ----------
  void _openFilterSheet() {
    String? tempProfession = _selectedProfession;
    String? tempCommunity = _selectedCommunity;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filter Customers',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),

                  const Text('Profession',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: tempProfession,
                    hint: const Text('All professions'),
                    decoration: InputDecoration(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    items: _professionOptions
                        .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                        .toList(),
                    onChanged: (val) {
                      setSheetState(() => tempProfession = val);
                    },
                  ),
                  const SizedBox(height: 16),

                  const Text('Community',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: tempCommunity,
                    hint: const Text('All communities'),
                    decoration: InputDecoration(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    items: _communityOptions
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (val) {
                      setSheetState(() => tempCommunity = val);
                    },
                  ),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setSheetState(() {
                              tempProfession = null;
                              tempCommunity = null;
                            });
                          },
                          child: const Text('Clear'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            setState(() {
                              _selectedProfession = tempProfession;
                              _selectedCommunity = tempCommunity;
                            });
                            _applyFilters();
                            Navigator.pop(sheetContext);
                          },
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ---------- Navigation ----------
  Future<void> _openForEdit(Map<String, dynamic> customer) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddCustomerScreen(
          employees: widget.employees,
          customers: _allCustomers,
          customerToEdit: customer,
        ),
      ),
    );
    if (result == true) _loadCustomers();
  }

  Future<void> _openAddCustomer() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddCustomerScreen(
          employees: widget.employees,
          customers: _allCustomers,
          customerToEdit: null,
        ),
      ),
    );
    if (result == true) _loadCustomers();
  }

  void _navigateToDashboard() {
    final role = widget.user['role']?.toString().toLowerCase();
    if (role == 'admin') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardScreen(user: widget.user),
        ),
      );
    } else if (role == 'employee') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => EmployeeDashboardScreen(user: widget.user),
        ),
      );
    } else {
      Navigator.pop(context);
    }
  }

  // ---------- Robust date parser ----------
  /// Returns (month, day) or null if parsing fails.
  (int month, int day)? _parseDate(String dateStr) {
    dateStr = dateStr.trim();

    if (dateStr.isEmpty) return null;

    if (dateStr.contains("T")) {
      dateStr = dateStr.split("T").first;
    }

    final parts = dateStr.split("-");

    try {
      if (parts.length == 2) {
        // DD-MM
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);

        return (month, day);
      }

      if (parts.length == 3) {
        // YYYY-MM-DD
        final month = int.parse(parts[1]);
        final day = int.parse(parts[2]);

        return (month, day);
      }
    } catch (_) {}

    return null;
  }

  // ---------- Build reminder chips (only if within next 4 days) ----------
  List<Widget> _buildReminderChips(Map<String, dynamic> customer) {
    final List<Widget> chips = [];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    void addReminder({
      required String? dateString,
      required bool birthday,
    }) {
      if (dateString == null || dateString.isEmpty) return;

      final parsed = _parseDate(dateString);

      if (parsed == null) return;

      final (month, day) = parsed;

      DateTime event = DateTime(now.year, month, day);

      if (event.compareTo(today) < 0) {
        event = DateTime(now.year + 1, month, day);
      }

      final diff = event.difference(today).inDays;

      if (diff < 0 || diff > 7) return;

      String text;

      if (birthday) {
        if (diff == 0) {
          text = "🎂 Birthday Today";
        } else if (diff == 1) {
          text = "🎂 Birthday Tomorrow";
        } else {
          text = "🎂 Birthday in $diff days";
        }
      } else {
        if (diff == 0) {
          text = "💍 Anniversary Today";
        } else if (diff == 1) {
          text = "💍 Anniversary Tomorrow";
        } else {
          text = "💍 Anniversary in $diff days";
        }
      }

      chips.add(
        _buildReminderChip(
          icon: birthday ? Icons.cake : Icons.favorite,
          label: text,
          diff: diff,
          isAnniversary: !birthday,
        ),
      );
    }

    addReminder(
      dateString: customer['birthday'],
      birthday: true,
    );

    addReminder(
      dateString: customer['anniversary'],
      birthday: false,
    );

    return chips;
  }

  Widget _buildReminderChip({
    required IconData icon,
    required String label,
    required int diff,
    bool isAnniversary = false,
  }) {
    // Colour based on urgency
    Color bgColor;
    Color textColor;
    if (diff == 0) {
      // Today
      bgColor = Colors.red.shade100;
      textColor = Colors.red.shade900;
    } else if (diff <= 2) {
      // Tomorrow / 2 days
      bgColor = Colors.orange.shade100;
      textColor = Colors.orange.shade900;
    } else if (diff <= 4) {
      // 3-4 days
      bgColor = Colors.amber.shade100;
      textColor = Colors.amber.shade900;
    } else {
      // 5-7 days
      bgColor = Colors.green.shade100;
      textColor = Colors.green.shade800;
    }
    return Container(
      margin: const EdgeInsets.only(right: 6, top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Build ----------
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _navigateToDashboard();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Customers'),
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _navigateToDashboard,
          ),
          actions: [
            IconButton(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.filter_list),
                  if (_selectedProfession != null || _selectedCommunity != null)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              onPressed: _openFilterSheet,
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search by name, phone, or profession...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: _clearSearch,
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
            ),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _filteredCustomers.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _loadCustomers,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _filteredCustomers.length,
                      itemBuilder: (context, index) {
                        final customer = _filteredCustomers[index];
                        final name = (customer['name'] ?? '').toString();
                        final phone = (customer['phone'] ?? '').toString();
                        final profession = (customer['profession'] ?? '').toString();
                        final reminderChips = _buildReminderChips(customer);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _openForEdit(customer),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  // Avatar
                                  Builder(
                                    builder: (context) {
                                      final customerImage = customer['customerImage']?.toString();
                                      final hasImage = customerImage != null && customerImage.isNotEmpty;

                                      if (!hasImage) {
                                        return CircleAvatar(
                                          radius: 28,
                                          backgroundColor: AppColors.primary.withOpacity(0.1),
                                          child: Text(
                                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                                            style: const TextStyle(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 20,
                                            ),
                                          ),
                                        );
                                      }

                                      return ClipOval(
                                        child: Image.network(
                                          ApiService.getImageUrl(customerImage),
                                          width: 56,
                                          height: 56,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => CircleAvatar(
                                            radius: 28,
                                            backgroundColor: AppColors.primary.withOpacity(0.1),
                                            child: Text(
                                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                                              style: const TextStyle(
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 20,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 16),
                                  // Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.phone,
                                              size: 14,
                                              color: Colors.grey,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              phone,
                                              style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (profession.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.work_outline,
                                                size: 14,
                                                color: Colors.grey,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                profession,
                                                style: const TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                        // Reminder chips – only if within 4 days
                                        if (reminderChips.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 4,
                                            runSpacing: 2,
                                            children: reminderChips,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right,
                                    color: Colors.grey,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
        floatingActionButton: FloatingActionButton(
          onPressed: _openAddCustomer,
          backgroundColor: AppColors.primary,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No customers found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to add your first customer.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _openAddCustomer,
            icon: const Icon(Icons.add),
            label: const Text('Add Customer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ],
      ),
    );
  }
}