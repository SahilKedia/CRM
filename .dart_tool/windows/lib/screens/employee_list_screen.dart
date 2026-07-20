// screens/employee_list_screen.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'save_employee_screen.dart';

class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  final ApiService _apiService = ApiService();

  List<Map<String, dynamic>> _employees = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchEmployees();
  }

  Future<void> _fetchEmployees() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.getEmployees();

      if (response['success'] == true) {
        setState(() {
          _employees = List<Map<String, dynamic>>.from(response['data']);
        });
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Failed to load employees';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToEdit(Map<String, dynamic> employee) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SaveEmployeeScreen(employee: employee),
      ),
    );
    if (result != null) {
      _fetchEmployees();
    }
  }

  Future<void> _deleteEmployee(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 10),
            Text('Delete Profile', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('Are you sure you want to delete "$name"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.shade400,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await _apiService.deleteEmployee(id);
      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Employee removed securely'), 
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        _fetchEmployees();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Employees',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, letterSpacing: -0.5),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 24),
            onPressed: _fetchEmployees,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SaveEmployeeScreen()),
          );
          if (result != null) _fetchEmployees();
        },
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Employee', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3));
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 64, color: Colors.redAccent.shade100),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _fetchEmployees,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry Connection'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_employees.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.badge_outlined, size: 72, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No employees listed yet.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchEmployees,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 84), // Extra bottom padding for FAB
        itemCount: _employees.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final employee = _employees[index];
          return _buildSwipeableEmployeeCard(employee);
        },
      ),
    );
  }

  Widget _buildSwipeableEmployeeCard(Map<String, dynamic> employee) {
    final id = employee['_id'] ?? '';
    final name = employee['name'] ?? 'Unknown';

    // Wrapping card with Dismissible for fluid swipe actions
    return Dismissible(
      key: Key(id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: Colors.redAccent.shade100.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 28),
            SizedBox(height: 2),
            Text('Delete', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        await _deleteEmployee(id, name);
        return false; // Dynamic refresh handles implementation rather than dismissing node implicitly
      },
      child: _buildEmployeeCard(employee),
    );
  }

  Widget _buildEmployeeCard(Map<String, dynamic> employee) {
    final id = employee['_id'] ?? '';
    final name = employee['name'] ?? 'Unknown';
    final email = employee['email'] ?? '';
    final phone = employee['phone'] ?? '';
    final department = employee['department'] ?? '';
    final branchName = employee['branch'] is Map ? employee['branch']['name'] ?? '' : '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _navigateToEdit(employee),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Structured Avatar Block
              CircleAvatar(
  radius: 26,
  backgroundColor: AppColors.primary.withOpacity(0.08),
  child: Text(
    name.isNotEmpty ? name[0].toUpperCase() : '?',
    style: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w900, // <--- Fixed here!
      color: AppColors.primary,
    ),
  ),
),
                  const SizedBox(width: 14),
                  
                  // Text and Info Chips Block
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (department.isNotEmpty)
                              _buildInfoChip(department, Colors.blue.shade50, Colors.blue.shade700),
                            if (branchName.isNotEmpty)
                              _buildInfoChip(branchName, Colors.amber.shade50, Colors.amber.shade800),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (email.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Icon(Icons.mail_outline_rounded, size: 14, color: Colors.grey.shade400),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    email,
                                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (phone.isNotEmpty)
                          Row(
                            children: [
                              Icon(Icons.phone_iphone_rounded, size: 14, color: Colors.grey.shade400),
                              const SizedBox(width: 6),
                              Text(
                                phone,
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  
                  // Premium Segmented Quick-Action Control Buttons Block
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(Icons.edit_note_rounded, color: AppColors.primary.withOpacity(0.8), size: 24),
                        tooltip: 'Edit Profile',
                        onPressed: () => _navigateToEdit(employee),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(Icons.delete_outline_rounded, color: Colors.redAccent.shade200, size: 22),
                        tooltip: 'Delete Profile',
                        onPressed: () => _deleteEmployee(id, name),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, Color background, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textColor),
      ),
    );
  }
}