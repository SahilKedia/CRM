import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'branch_list_screen.dart';
import 'employee_list_screen.dart';
import 'customer_list_screen.dart';
import 'reports_screen.dart';
import 'user_detail_screen.dart';
import 'admin_list_screen.dart';    // if the file is in the same folder

class SuperAdminDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const SuperAdminDashboardScreen({super.key, required this.user});

  @override
  State<SuperAdminDashboardScreen> createState() =>
      _SuperAdminDashboardScreenState();
}

class _SuperAdminDashboardScreenState
    extends State<SuperAdminDashboardScreen> {
  int _totalBranches = 0;
  int _totalEmployees = 0;
  int _totalCustomers = 0;
  int _totalAdmins = 0; // No admin-count endpoint yet → remains 0

  List<Map<String, dynamic>> _employees = [];

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch all three in parallel – no branch filters, so we get **all** data
      await Future.wait([
        _fetchBranches(),
        _fetchEmployees(),
        _fetchCustomers(),
        _fetchAdmins(),   // <-- added

      ]);

      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load data: $e';
        _isLoading = false;
      });
    }
  }
  Future<void> _fetchAdmins() async {
  try {
    final response = await ApiService().getAdmins(); // uses the existing getAdmins()
    if (response['success'] == true) {
      final data = response['admins'] ?? response['data'];
      if (data is List) {
        setState(() => _totalAdmins = data.length);
      }
    }
  } catch (e) {
    print('❌ Error fetching admins: $e');
  }
}
  Future<void> _fetchBranches() async {
    try {
      final response = await ApiService().getBranches();
      if (response['success'] == true) {
        final data = response['branches'] ?? response['data'];
        if (data is List) {
          setState(() => _totalBranches = data.length);
        }
      }
    } catch (e) {
      print('❌ Error fetching branches: $e');
    }
  }

  Future<void> _fetchEmployees() async {
    try {
      final response = await ApiService().getEmployees(); // ← no branch param
      if (response['success'] == true) {
        final data = response['employees'] ?? response['data'];
        if (data is List) {
          setState(() {
            _employees = List<Map<String, dynamic>>.from(data);
            _totalEmployees = _employees.length;
          });
        }
      }
    } catch (e) {
      print('❌ Error fetching employees: $e');
    }
  }

  Future<void> _fetchCustomers() async {
    try {
      final response = await ApiService().getCustomers(); // ← all customers
      if (response['success'] == true) {
        final data = response['customers'] ?? response['data'];
        if (data is List) {
          setState(() => _totalCustomers = data.length);
        }
      }
    } catch (e) {
      print('❌ Error fetching customers: $e');
    }
  }

  void _navigateToBranches() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BranchListScreen()),
    );
    _fetchBranches();
  }

  void _navigateToEmployees() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EmployeeListScreen()),
    );
    _fetchEmployees();
  }

  void _navigateToCustomers() async {
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

  void _navigateToReports() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ReportsScreen()),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature screen is coming soon'),
        backgroundColor: Colors.grey[700],
      ),
    );
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.indigo,
        title: const Text(
          "Super Admin Dashboard",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UserDetailScreen(user: widget.user),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _handleLogout,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 64, color: Colors.red.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Welcome Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: const LinearGradient(
                              colors: [Color(0xff3949AB), Color(0xff5C6BC0)],
                            ),
                          ),
                          child: Row(
                            children: [
                              const CircleAvatar(
                                radius: 30,
                                backgroundColor: Colors.white,
                                child: Icon(
                                  Icons.admin_panel_settings,
                                  color: Color(0xff3949AB),
                                  size: 35,
                                ),
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Welcome ${widget.user["name"] ?? ""}",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      widget.user["email"] ?? "",
                                      style: const TextStyle(color: Colors.white70),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      "Role : ${widget.user["role"] ?? ""}",
                                      style: const TextStyle(color: Colors.white70),
                                    ),
                                  ],
                                ),
                              )
                            ],
                          ),
                        ),
                        const SizedBox(height: 25),
                        const Text(
                          "Overview",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 20),
                        ),
                        const SizedBox(height: 15),
                        Row(
                          children: [
                            Expanded(
                              child: _statCard(
                                "Branches",
                                _totalBranches.toString(),
                                Icons.business,
                                Colors.orange,
                                onTap: _navigateToBranches,
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: _statCard(
                                "Admins",
                                _totalAdmins.toString(),
                                Icons.admin_panel_settings,
                                Colors.indigo,
                                onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const AdminListScreen()),
  );
},
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Row(
                          children: [
                            Expanded(
                              child: _statCard(
                                "Employees",
                                _totalEmployees.toString(),
                                Icons.people,
                                Colors.green,
                                onTap: _navigateToEmployees,
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: _statCard(
                                "Customers",
                                _totalCustomers.toString(),
                                Icons.groups,
                                Colors.blue,
                                onTap: _navigateToCustomers,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),
                        const Text(
                          "Quick Actions",
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 15),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: 15,
                          mainAxisSpacing: 15,
                          childAspectRatio: 1.1,
                          children: [
                            _actionCard(
                              Icons.business,
                              "Manage\nBranches",
                              Colors.orange,
                              onTap: _navigateToBranches,
                            ),
                            _actionCard(
                               Icons.admin_panel_settings,
                               "Manage\nAdmins",
                               Colors.indigo,
                               onTap: () {
                               Navigator.push(
                               context,
                               MaterialPageRoute(builder: (_) => const AdminListScreen()),
                                 );
                               },
                              ),
                            _actionCard(
                              Icons.people,
                              "Manage\nEmployees",
                              Colors.green,
                              onTap: _navigateToEmployees,
                            ),
                            _actionCard(
                              Icons.groups,
                              "All\nCustomers",
                              Colors.blue,
                              onTap: _navigateToCustomers,
                            ),
                            _actionCard(
                              Icons.analytics,
                              "Reports",
                              Colors.red,
                              onTap: _navigateToReports,
                            ),
                            _actionCard(
                              Icons.settings,
                              "Settings",
                              Colors.grey,
                              onTap: () => _showComingSoon('Settings'),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _statCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              blurRadius: 8,
              color: Colors.grey.withOpacity(.12),
            )
          ],
        ),
        child: Column(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(.15),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
            ),
            const SizedBox(height: 5),
            Text(title),
          ],
        ),
      ),
    );
  }

  Widget _actionCard(
    IconData icon,
    String title,
    Color color, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(.12),
              blurRadius: 8,
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: color.withOpacity(.15),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(height: 15),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            )
          ],
        ),
      ),
    );
  }
}