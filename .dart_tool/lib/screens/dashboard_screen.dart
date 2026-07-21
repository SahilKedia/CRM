// screens/dashboard_screen.dart (UI REVAMPED — modern, layered, "real app" feel)
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/crm_text_field.dart';
import 'login_screen.dart';
import 'add_employee_screen.dart';
import 'add_customer_screen.dart';
import '../services/api_service.dart';
import 'reports_screen.dart';
import 'employee_list_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'add_branch_screen.dart';
import 'customer_list_screen.dart';
import 'review_screen.dart';
import 'branch_list_screen.dart';
// import 'notification_screen.dart';
import 'user_detail_screen.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';
import 'reminders_screen.dart';
import 'pending_requirements_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const DashboardScreen({
    Key? key,
    required this.user,
  }) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  // Data variables
  int _totalEmployees = 0;
  int _totalCustomers = 0;
  int _totalBranches = 0;
  int _pendingRequirementsCount = 0;
  int _upcomingReminderCount = 0;

  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _employees = [];

  bool _isLoading = false;
  String? _error;

  // Used to give the customers-tab search bar a subtle raised state.
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // Date / reminder helpers
  // ------------------------------------------------------------

  // Recurring events (birthday/anniversary) are stored as "DD-MM" — no year.
  (int month, int day)? _parseDate(String dateStr) {
    dateStr = dateStr.trim();
    if (dateStr.isEmpty) return null;
    if (dateStr.contains("T")) {
      dateStr = dateStr.split("T").first;
    }
    final parts = dateStr.split("-");
    try {
      if (parts.length == 2) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        return (month, day);
      }
      if (parts.length == 3) {
        final month = int.parse(parts[1]);
        final day = int.parse(parts[2]);
        return (month, day);
      }
    } catch (_) {}
    return null;
  }

  // One-time reminders are stored as a full ISO datetime — keep the real
  // year/time instead of collapsing it to a recurring month/day like
  // birthdays/anniversaries.
  DateTime? _parseFullDate(String dateStr) {
    return DateTime.tryParse(dateStr)?.toLocal();
  }

  // ✅ FIXED: reminders now use the real date+time (not month/day-only),
  // and a reminder whose exact time has already passed is excluded —
  // matches the same rule used on the Reminders screen.
  int _countUpcomingReminders() {
    int count = 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (var customer in _customers) {
      // Birthday / anniversary — recurring, month/day only
      void checkDate(String? dateStr) {
        if (dateStr == null || dateStr.isEmpty) return;
        final parsed = _parseDate(dateStr);
        if (parsed == null) return;
        final (month, day) = parsed;
        DateTime event = DateTime(now.year, month, day);
        if (event.compareTo(today) < 0) {
          event = DateTime(now.year + 1, month, day);
        }
        final diff = event.difference(today).inDays;
        if (diff >= 0 && diff <= 7) count++;
      }

      checkDate(customer['birthday']);
      checkDate(customer['anniversary']);

      // Jewellery / follow-up reminders — one-time, exact date & time
      final reminderData = customer['reminder'];
      if (reminderData != null) {
        List reminders = [];
        if (reminderData is List) {
          reminders = reminderData;
        } else if (reminderData is Map) {
          reminders = [reminderData];
        }

        // Count every reminder that is still pending, regardless of its date —
        // keeps counting whether upcoming or overdue, and only stops once it's
        // marked 'completed' (matches RemindersScreen behavior).
        for (var reminder in reminders) {
          if (reminder['status'] != 'pending') continue;

          final dateStr = reminder['date']?.toString();
          if (dateStr == null || dateStr.isEmpty) continue;

          final eventDateTime = _parseFullDate(dateStr);
          if (eventDateTime == null) continue;

          count++;
        }
      }
    }
    return count;
  }

  void _navigateToReminders() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RemindersScreen(
          customers: _customers,
          user: widget.user,
        ),
      ),
    );
    await _fetchCustomers();
  }

  // ------------------------------------------------------------
  // Drawer navigation
  // ------------------------------------------------------------
  void _onSidebarItemTapped(int index) {
    Navigator.pop(context);

    if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const BranchListScreen(),
        ),
      ).then((_) => _fetchBranches());
      return;
    }

    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) {
      _loadData();
    } else if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CustomerListScreen(
            user: widget.user,
            employees: _employees,
          ),
        ),
      );
    } else if (index == 4) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReviewScreen(
            user: widget.user,
          ),
        ),
      );
    }
  }

  Future<void> _fetchPendingRequirementsCount() async {
    try {
      final apiService = ApiService();
      final response = await apiService.getPendingRequirements();
      if (response['success'] == true) {
        final data = response['data'] as List? ?? [];
        if (mounted) {
          setState(() => _pendingRequirementsCount = data.length);
        }
      }
    } catch (e) {
      print('⚠️ Could not fetch pending requirements: $e');
    }
  }

  void _navigateToPendingRequirements() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PendingRequirementsScreen()),
    );
    _fetchPendingRequirementsCount();
  }

  // ------------------------------------------------------------
  // Data loading
  // ------------------------------------------------------------
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await Future.wait([
        _fetchEmployees(),
        _fetchCustomers(),
        _fetchBranches(),
        _fetchPendingRequirementsCount(),
      ]);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load data: $e';
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading data: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _fetchEmployees() async {
    try {
      final apiService = ApiService();
      final response = await apiService.getEmployees();

      if (response['success'] == true) {
        if (!mounted) return;
        final employeesData = response['employees'] ?? response['data'];

        if (employeesData != null && employeesData is List) {
          setState(() {
            _employees = List<Map<String, dynamic>>.from(employeesData);
            _totalEmployees = _employees.length;
          });
        } else {
          setState(() {
            _employees = [];
            _totalEmployees = 0;
          });
        }
      } else {
        setState(() {
          _employees = [];
          _totalEmployees = 0;
        });
      }
    } catch (e) {
      setState(() {
        _employees = [];
        _totalEmployees = 0;
      });
    }
  }

  Future<void> _fetchCustomers() async {
    try {
      final apiService = ApiService();
      final response = await apiService.getCustomers();

      if (response['success'] == true) {
        if (!mounted) return;
        final customersData = response['customers'] ?? response['data'];

        if (customersData != null && customersData is List) {
          setState(() {
            _customers = List<Map<String, dynamic>>.from(customersData);
            _totalCustomers = _customers.length;
            _upcomingReminderCount = _countUpcomingReminders();
          });

          // Re-establish local alarms from the DB — the DB reminder field
          // is the source of truth, so this covers reinstalls, cleared
          // alarms, device reboots (if the manifest receiver is missing),
          // or a reminder that was added from a different device/session.
          await NotificationService().resyncPendingReminders(_customers);
        } else {
          setState(() {
            _customers = [];
            _totalCustomers = 0;
            _upcomingReminderCount = 0;
          });
        }
      } else {
        setState(() {
          _customers = [];
          _totalCustomers = 0;
          _upcomingReminderCount = 0;
        });
      }
    } catch (e) {
      setState(() {
        _customers = [];
        _totalCustomers = 0;
        _upcomingReminderCount = 0;
      });
    }
  }

  Future<void> _fetchBranches() async {
    try {
      final apiService = ApiService();
      final response = await apiService.getBranches();

      if (response['success'] == true) {
        if (!mounted) return;
        final branchesData = response['branches'] ?? response['data'];
        if (branchesData != null && branchesData is List) {
          setState(() {
            _totalBranches = branchesData.length;
          });
        }
      }
    } catch (e) {
      // silent
    }
  }

  // ------------------------------------------------------------
  // Navigation helpers
  // ------------------------------------------------------------
  void _navigateToAddEmployee() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddEmployeeScreen(),
      ),
    );

    if (result != null && mounted) {
      await _fetchEmployees();
      if (!mounted) return;
      _showSuccessSnack('Employee added successfully!');
    }
  }

  void _navigateToAddCustomer() async {
    if (_employees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please add an employee first before adding customers'),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddCustomerScreen(
          employees: _employees,
          customers: _customers,
        ),
      ),
    );

    if (result != null && mounted) {
      await _fetchCustomers();
      if (!mounted) return;
      _showSuccessSnack('Customer added successfully!');
    }
  }

  void _navigateToAddBranch() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddBranchScreen(),
      ),
    );

    if (result != null && mounted) {
      await _fetchBranches();
      if (!mounted) return;
      _showSuccessSnack('Branch added successfully!');
    }
  }

  void _showSuccessSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(message),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _navigateToBranchList() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BranchListScreen()),
    );
    _fetchBranches();
  }

  void _navigateToEmployeeList() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EmployeeListScreen()),
    );
    _fetchEmployees();
  }

  void _navigateToCustomerList() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerListScreen(
          user: widget.user,
          employees: _employees,
        ),
      ),
    );
    _fetchCustomers();
  }

  // ------------------------------------------------------------
  // Delete methods
  // ------------------------------------------------------------
  void _deleteCustomer(String customerId) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final apiService = ApiService();
      final response = await apiService.deleteCustomer(customerId);

      if (response['success'] == true) {
        await _fetchCustomers();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Customer deleted successfully'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pop(context);
      } else {
        throw Exception(response['message'] ?? 'Failed to delete customer');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting customer: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _deleteEmployee(String employeeId) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final apiService = ApiService();
      final response = await apiService.deleteEmployee(employeeId);

      if (response['success'] == true) {
        await _fetchEmployees();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Employee deleted successfully'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pop(context);
      } else {
        throw Exception(response['message'] ?? 'Failed to delete employee');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting employee: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ------------------------------------------------------------
  // Small helpers for the UI
  // ------------------------------------------------------------
  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _todayLabel() {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final now = DateTime.now();
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';
  }

  String _initials(String name) {
    if (name.trim().isEmpty) return 'U';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  List<Map<String, dynamic>> get _filteredCustomers {
    if (_searchQuery.trim().isEmpty) return _customers;
    final q = _searchQuery.toLowerCase();
    return _customers.where((c) {
      final name = (c['name'] ?? '').toString().toLowerCase();
      final email = (c['email'] ?? '').toString().toLowerCase();
      final phone = (c['phone'] ?? '').toString().toLowerCase();
      return name.contains(q) || email.contains(q) || phone.contains(q);
    }).toList();
  }

  // ------------------------------------------------------------
  // Build methods
  // ------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FA),
      drawer: _buildDrawer(),
      appBar: _buildAppBar(),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _isLoading
            ? const Center(
                key: ValueKey('loading'),
                child: CircularProgressIndicator(),
              )
            : _error != null
                ? _buildErrorState()
                : KeyedSubtree(
                    key: ValueKey(_selectedIndex),
                    child: _getBody(),
                  ),
      ),
      floatingActionButton: _getFloatingActionButton(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.wifi_off_rounded,
                size: 48,
                color: AppColors.error.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboard();
      case 1:
        return _buildCustomers();
      case 4:
        return _buildDashboard();
      default:
        return _buildDashboard();
    }
  }

  Widget? _getFloatingActionButton() {
    if (_selectedIndex == 1) {
      return FloatingActionButton.extended(
        onPressed: _navigateToAddCustomer,
        backgroundColor: AppColors.primary,
        elevation: 2,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Customer', style: TextStyle(color: Colors.white)),
      );
    }
    return null;
  }

  // ------------------------------------------------------------
  // Drawer
  // ------------------------------------------------------------
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 56, 24, 28),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  right: -24,
                  top: -30,
                  child: Icon(Icons.diamond_rounded, size: 110, color: Colors.white.withOpacity(0.08)),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.15),
                        border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 4)),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _initials(widget.user["name"] ?? "User"),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      widget.user["name"] ?? "User",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.user["email"] ?? "",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        (widget.user["role"] ?? "").toString().toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _buildDrawerTile(Icons.dashboard_rounded, 'Dashboard', 0),
          _buildDrawerTile(Icons.people_alt_rounded, 'Customers', 1),
          _buildDrawerTile(Icons.storefront_rounded, 'Branches', 3),

          _drawerDivider(),

          _buildDrawerActionTile(Icons.analytics_rounded, 'Reports', () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReportsScreen()),
            );
          }),
          _buildDrawerActionTile(Icons.list_alt_rounded, 'Employee List', () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EmployeeListScreen()),
            );
          }),

          _drawerDivider(),

          _buildDrawerTile(Icons.feedback_rounded, 'Reviews', 4),

          const Spacer(),
          _drawerDivider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              leading: const Icon(Icons.logout_rounded, color: Colors.red),
              title: const Text(
                'Logout',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(context);
                _logout();
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _drawerDivider() => const Divider(height: 1, indent: 20, endIndent: 20);

  Widget _buildDrawerTile(IconData icon, String title, int index) {
    final selected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected ? AppColors.primary.withOpacity(0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _onSidebarItemTapped(index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 4,
                  height: 26,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Icon(
                  icon,
                  size: 22,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5,
                    color: selected ? AppColors.primary : AppColors.textPrimary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerActionTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }

  // ------------------------------------------------------------
  // Logout
  // ------------------------------------------------------------
  void _logout() {
    _handleLogout();
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AuthService.logout();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  // ------------------------------------------------------------
  // AppBar
  // ------------------------------------------------------------
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: const Color(0xFFF3F5FA),
      foregroundColor: AppColors.textPrimary,
      titleSpacing: 4,
      title: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.accent],
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/icon.jpg',
                width: 34,
                height: 34,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'MRJ CRM',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 19,
              color: AppColors.textPrimary,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.person_outline_rounded, size: 20),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UserDetailScreen(user: widget.user),
              ),
            );
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // ------------------------------------------------------------
  // DASHBOARD
  // ------------------------------------------------------------
  Widget _buildDashboard() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- HERO / WELCOME CARD ----
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    right: -18,
                    top: -28,
                    child: Icon(
                      Icons.diamond_rounded,
                      size: 100,
                      color: Colors.white.withOpacity(0.09),
                    ),
                  ),
                  Positioned(
                    right: 40,
                    bottom: -30,
                    child: Icon(
                      Icons.diamond_outlined,
                      size: 60,
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.16),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 12, color: Colors.white),
                                const SizedBox(width: 6),
                                Text(
                                  _todayLabel(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${_greeting()}, ${(widget.user["name"] ?? "Admin").toString().split(' ').first}!',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Here's what's happening with your business today.",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _heroPill(Icons.people_alt_rounded, '$_totalEmployees Employees'),
                          _heroPill(Icons.person_rounded, '$_totalCustomers Customers'),
                          _heroPill(Icons.storefront_rounded, '$_totalBranches Branches'),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // ---- STATS GRID ----
            // CHANGED: was a 5-item GridView.count(crossAxisCount: 2) which left
            // "Requirements" stranded alone on its own row (half width, big empty
            // gap next to it). Now: a clean 2x2 grid for the first four stats,
            // plus a full-width card for the fifth so nothing looks orphaned.
            _sectionHeader('Overview'),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.15,
              children: [
                _buildStatCard(
                  'Employees',
                  _totalEmployees.toString(),
                  Icons.people_alt_rounded,
                  const Color(0xFF4CAF50),
                  onTap: _navigateToEmployeeList,
                ),
                _buildStatCard(
                  'Customers',
                  _totalCustomers.toString(),
                  Icons.person_rounded,
                  const Color(0xFF2196F3),
                  onTap: _navigateToCustomerList,
                ),
                _buildStatCard(
                  'Branches',
                  _totalBranches.toString(),
                  Icons.storefront_rounded,
                  const Color(0xFFFF9800),
                  onTap: _navigateToBranchList,
                ),
                _buildStatCard(
                  'Reminders',
                  '$_upcomingReminderCount',
                  Icons.notifications_active_rounded,
                  const Color(0xFFE91E63),
                  onTap: _navigateToReminders,
                  badge: _upcomingReminderCount > 0,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildWideStatCard(
              'Pending Requirements',
              _pendingRequirementsCount.toString(),
              Icons.inventory_2_rounded,
              const Color(0xFF00BCD4),
              onTap: _navigateToPendingRequirements,
              badge: _pendingRequirementsCount > 0,
            ),
            const SizedBox(height: 26),

            // ---- QUICK ACTIONS ----
           _sectionHeader('Quick Actions'),
const SizedBox(height: 12),

SizedBox(
  height: 130, // Increased from 104
  child: ListView(
    scrollDirection: Axis.horizontal,
    physics: const BouncingScrollPhysics(),
    children: [
      _buildQuickActionCard(
        'Add\nEmployee',
        Icons.person_add_alt_1_rounded,
        const Color(0xFF4CAF50),
        _navigateToAddEmployee,
      ),
      const SizedBox(width: 12),
      _buildQuickActionCard(
        'Add\nCustomer',
        Icons.person_add_rounded,
        const Color(0xFF2196F3),
        _navigateToAddCustomer,
      ),
      const SizedBox(width: 12),
      _buildQuickActionCard(
        'View\nReports',
        Icons.analytics_rounded,
        const Color(0xFF9C27B0),
        () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ReportsScreen(),
            ),
          );
        },
      ),
      const SizedBox(width: 12),
      _buildQuickActionCard(
        'Add\nBranch',
        Icons.add_business_rounded,
        const Color(0xFF607D8B),
        _navigateToAddBranch,
      ),
    ],
  ),
),
const SizedBox(height: 26),

            // ---- RECENT CUSTOMERS ----
            _sectionHeader(
              'Recent Customers',
              trailing: _customers.isEmpty
                  ? null
                  : TextButton.icon(
                      onPressed: _navigateToCustomerList,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Text('See all', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      label: const Icon(Icons.arrow_forward_ios_rounded, size: 12),
                    ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                clipBehavior: Clip.antiAlias,
                child: _customers.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 36),
                        child: Column(
                          children: [
                            Icon(Icons.people_outline_rounded, size: 40, color: AppColors.textSecondary.withOpacity(0.4)),
                            const SizedBox(height: 10),
                            const Text(
                              'No customers yet',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: _customers.length > 3 ? 3 : _customers.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 68),
                        itemBuilder: (context, index) {
                          final customer = _customers[index];
                          final name = (customer['name'] ?? '') as String;
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primary.withOpacity(0.5),
                                    AppColors.accent.withOpacity(0.5),
                                  ],
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 19,
                                backgroundColor: Colors.white,
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14.5,
                              ),
                            ),
                            subtitle: Text(
                              customer['email'] ?? '',
                              style: const TextStyle(fontSize: 12.5),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.textSecondary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                customer['createdAt']?.toString().substring(0, 10) ?? '',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary.withOpacity(0.9),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            onTap: () {},
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, {Widget? trailing}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  // ------------------------------------------------------------
  // Stat Card
  // ------------------------------------------------------------
  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
    bool badge = false,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.10),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              // left accent strip
              Positioned(
                left: 0,
                top: 14,
                bottom: 14,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [color.withOpacity(0.18), color.withOpacity(0.08)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, color: color, size: 20),
                        ),
                        if (badge)
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE91E63),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFE91E63).withOpacity(0.5),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          value,
                          style: const TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.chevron_right_rounded, size: 14, color: AppColors.textSecondary.withOpacity(0.6)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // Wide Stat Card (full-width; used for the 5th/odd-one-out stat
  // so the Overview section never leaves a lonely half-empty cell)
  // ------------------------------------------------------------
  Widget _buildWideStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
    bool badge = false,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.10),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 14,
                bottom: 14,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color.withOpacity(0.18), color.withOpacity(0.08)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            value,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (badge)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE91E63),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE91E63).withOpacity(0.5),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textSecondary.withOpacity(0.6)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // Quick Action Card (horizontal capsule)
  // ------------------------------------------------------------
  Widget _buildQuickActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 92,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.10),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.2), color.withOpacity(0.08)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.15,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // CUSTOMERS TAB
  // ------------------------------------------------------------
  Widget _buildCustomers() {
    final list = _filteredCustomers;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search customers...',
                      hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.7), fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded, color: AppColors.textSecondary.withOpacity(0.7)),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _navigateToAddCustomer,
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Add'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_customers.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${list.length} customer${list.length == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary.withOpacity(0.8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        Expanded(
          child: list.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline_rounded, size: 48, color: AppColors.textSecondary.withOpacity(0.35)),
                      const SizedBox(height: 12),
                      Text(
                        _customers.isEmpty ? 'No customers found' : 'No matches for "$_searchQuery"',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final customer = list[index];
                    final name = (customer['name'] ?? '') as String;
                    final assignedTo = customer['assignedTo'];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _showCustomerActions(customer),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(2.5),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.primary.withOpacity(0.6),
                                        AppColors.accent.withOpacity(0.6),
                                      ],
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 22,
                                    backgroundColor: Colors.white,
                                    child: Text(
                                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(customer['email'] ?? '', style: const TextStyle(fontSize: 12.5)),
                                      if (customer['phone'] != null && (customer['phone'] as String).isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 3),
                                          child: Row(
                                            children: [
                                              Icon(Icons.phone_rounded, size: 12, color: AppColors.textSecondary.withOpacity(0.7)),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${customer['phone']}',
                                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withOpacity(0.9)),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (assignedTo != null)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 3),
                                          child: Row(
                                            children: [
                                              Icon(Icons.person_rounded, size: 12, color: AppColors.textSecondary.withOpacity(0.7)),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${assignedTo['name'] ?? assignedTo}',
                                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withOpacity(0.9)),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (customer['status'] != null)
                                        Container(
                                          margin: const EdgeInsets.only(top: 7),
                                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(customer['status']).withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            customer['status'],
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              color: _getStatusColor(customer['status']),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.more_vert, color: AppColors.textSecondary.withOpacity(0.8)),
                                  onPressed: () => _showCustomerActions(customer),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Active':
        return Colors.green;
      case 'Inactive':
        return Colors.red;
      case 'Lead':
        return Colors.blue;
      case 'Prospect':
        return Colors.orange;
      case 'Vendor':
        return Colors.purple;
      case 'pending':
        return Colors.orange;
      case 'in-progress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showCustomerActions(Map<String, dynamic> customer) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: AppColors.primary),
              title: const Text('Edit Customer'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Customer'),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(customer);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info, color: AppColors.primary),
              title: const Text('View Details'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> customer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Customer'),
        content: Text('Are you sure you want to delete ${customer['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _deleteCustomer(customer['_id']);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}