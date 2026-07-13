import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'admin_edit_screen.dart'; // we'll create this

class AdminListScreen extends StatefulWidget {
  const AdminListScreen({super.key});

  @override
  State<AdminListScreen> createState() => _AdminListScreenState();
}

class _AdminListScreenState extends State<AdminListScreen> {
  List<Map<String, dynamic>> _admins = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAdmins();
  }

  Future<void> _loadAdmins() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await ApiService().getAdmins();
      if (response['success'] == true) {
        setState(() {
          _admins = List<Map<String, dynamic>>.from(response['admins'] ?? []);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response['message'] ?? 'Failed to load admins';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteAdmin(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Admin'),
        content: const Text('Are you sure you want to delete this admin?'),
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
    if (confirm != true) return;

    try {
      final response = await ApiService().deleteAdmin(id);
      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Admin deleted successfully')),
        );
        _loadAdmins(); // refresh list
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'] ?? 'Failed to delete')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Admins'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // Navigate to signup screen with role pre-filled as 'admin'
              // You need to create a signup screen that can accept an initial role
              // For now, we'll just show a snackbar.
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Add admin via signup screen')),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadAdmins,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _admins.isEmpty
                  ? const Center(child: Text('No admins found'))
                  : ListView.builder(
                      itemCount: _admins.length,
                      itemBuilder: (context, index) {
                        final admin = _admins[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.admin_panel_settings),
                            ),
                            title: Text(admin['name'] ?? 'No Name'),
                            subtitle: Text(admin['email'] ?? 'No Email'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => AdminEditScreen(admin: admin),
                                      ),
                                    );
                                    if (result == true) {
                                      _loadAdmins(); // refresh after edit
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteAdmin(admin['_id']),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}