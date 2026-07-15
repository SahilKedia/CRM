// screens/dashboard_screen.dart (UI IMPROVED)
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
import 'pending_requirements_screen.dart';   // ✅ add


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
  int _pendingRequirementsCount = 0;   // ✅ add


  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _employees = [];

  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ------------------------------------------------------------
  // Date / reminder helpers (unchanged logic)
  // ------------------------------------------------------------
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

  int _countUpcomingReminders() {
    int count = 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (var customer in _customers) {
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
    }
    return count;
  }

  void _navigateToReminders() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RemindersScreen(
          customers: _customers,
          user: widget.user,
        ),
      ),
    );
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
      setState(() => _pendingRequirementsCount = data.length);
    }
  } catch (e) {
    // silent — matches _fetchBranches() pattern
  }
}


void _navigateToPendingRequirements() async {
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const PendingRequirementsScreen()),
  );
  _fetchPendingRequirementsCount(); // refresh badge after returning
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
          _fetchPendingRequirementsCount(),   // ✅ add

      ]);

      setState(() {
        _isLoading = false;
      });
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
          });
        } else {
          setState(() {
            _customers = [];
            _totalCustomers = 0;
          });
        }
      } else {
        setState(() {
          _customers = [];
          _totalCustomers = 0;
        });
      }
    } catch (e) {
      setState(() {
        _customers = [];
        _totalCustomers = 0;
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
  // Small helpers for the new UI
  // ------------------------------------------------------------
  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _initials(String name) {
    if (name.trim().isEmpty) return 'U';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  // ------------------------------------------------------------
  // Build methods
  // ------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
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
            Text(
              'Something went wrong',
              style: const TextStyle(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.15),
                    border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
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
                const SizedBox(height: 8),
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
          ),
          const SizedBox(height: 8),
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
      child: ListTile(
        tileColor: selected ? AppColors.primary.withOpacity(0.08) : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Icon(
          icon,
          color: selected ? AppColors.primary : AppColors.textSecondary,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: selected ? AppColors.primary : AppColors.textPrimary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        onTap: () => _onSidebarItemTapped(index),
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
      backgroundColor: const Color(0xFFF6F7FB),
      foregroundColor: AppColors.textPrimary,
      titleSpacing: 4,
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.accent],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.diamond_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          const Text(
            'CRM Pro',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 19,
              color: AppColors.textPrimary,
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
                  blurRadius: 4,
                  offset: const Offset(0, 1),
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
            // Welcome Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -10,
                    top: -20,
                    child: Icon(
                      Icons.diamond_rounded,
                      size: 90,
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_greeting()}, ${(widget.user["name"] ?? "Admin").toString().split(' ').first}!',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
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
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ---- STATS GRID ----
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.2,
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
                  '${_countUpcomingReminders()}',
                  Icons.notifications_active_rounded,
                  const Color(0xFFE91E63),
                  onTap: _navigateToReminders,
                  badge: _countUpcomingReminders() > 0,
                ),

                // ✅ add
_buildStatCard(
  'Requirements',
  '$_pendingRequirementsCount',
  Icons.inventory_2_rounded,
  const Color(0xFF00BCD4),
  onTap: _navigateToPendingRequirements,
  badge: _pendingRequirementsCount > 0,
),
              ],
            ),
            const SizedBox(height: 28),

            // Quick Actions
            _sectionHeader('Quick Actions'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionCard(
                    'Add Employee',
                    Icons.person_add_alt_1_rounded,
                    const Color(0xFF4CAF50),
                    _navigateToAddEmployee,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionCard(
                    'Add Customer',
                    Icons.person_add_rounded,
                    const Color(0xFF2196F3),
                    _navigateToAddCustomer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionCard(
                    'View Reports',
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
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionCard(
                    'Settings',
                    Icons.settings_rounded,
                    const Color(0xFF607D8B),
                    () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Navigate to Settings screen'),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // Recent Customers
            _sectionHeader('Recent Customers', trailing: _customers.isEmpty
                ? null
                : TextButton(
                    onPressed: _navigateToCustomerList,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('See all', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  )),
            const SizedBox(height: 8),
            Container(
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
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: _customers.length > 3 ? 3 : _customers.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 68),
                        itemBuilder: (context, index) {
                          final customer = _customers[index];
                          final name = (customer['name'] ?? '') as String;
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.primary.withOpacity(0.1),
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
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
                            trailing: Text(
                              customer['createdAt']?.toString().substring(0, 10) ?? '',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondary.withOpacity(0.8),
                                fontWeight: FontWeight.w500,
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
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 19),
                  ),
                  if (badge)
                    Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE91E63),
                        shape: BoxShape.circle,
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
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // Quick Action Card
  // ------------------------------------------------------------
  Widget _buildQuickActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
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
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search customers...',
                      hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.7), fontSize: 14),
                      prefixIcon: Icon(Icons.search, color: AppColors.textSecondary.withOpacity(0.7)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onChanged: (value) {},
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
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _customers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline_rounded, size: 48, color: AppColors.textSecondary.withOpacity(0.35)),
                      const SizedBox(height: 12),
                      const Text('No customers found', style: TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                  itemCount: _customers.length,
                  itemBuilder: (context, index) {
                    final customer = _customers[index];
                    final name = (customer['name'] ?? '') as String;
                    final assignedTo = customer['assignedTo'];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: CircleAvatar(
                          radius: 22,
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(customer['email'] ?? '', style: const TextStyle(fontSize: 12.5)),
                              if (customer['phone'] != null && (customer['phone'] as String).isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Row(
                                    children: [
                                      Icon(Icons.phone, size: 12, color: AppColors.textSecondary.withOpacity(0.7)),
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
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Row(
                                    children: [
                                      Icon(Icons.person, size: 12, color: AppColors.textSecondary.withOpacity(0.7)),
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
                                  margin: const EdgeInsets.only(top: 6),
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
                        trailing: IconButton(
                          icon: Icon(Icons.more_vert, color: AppColors.textSecondary.withOpacity(0.8)),
                          onPressed: () {
                            _showCustomerActions(customer);
                          },
                        ),
                        isThreeLine: true,
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