import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'add_branch_screen.dart';

class BranchListScreen extends StatefulWidget {
  const BranchListScreen({Key? key}) : super(key: key);

  @override
  State<BranchListScreen> createState() => _BranchListScreenState();
}

class _BranchListScreenState extends State<BranchListScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _branches = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _apiService.getBranches();
      if (response['success'] == true) {
        final list = (response['data'] ?? response['branches'] ?? []) as List;
        setState(() {
          _branches = list.cast<Map<String, dynamic>>();
        });
      } else {
        setState(() => _error = response['message'] ?? 'Failed to load branches');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _goToAddBranch() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddBranchScreen()),
    );
    if (result != null) _loadBranches();
  }

  Future<void> _goToEditBranch(Map<String, dynamic> branch) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddBranchScreen(branch: branch)),
    );
    if (result != null) _loadBranches();
  }

  // Modern Bottom Sheet Menu
 // Modern Bottom Sheet Menu
  void _showActionOptions(Map<String, dynamic> branch) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Minimalist grab handle indicator
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      branch['name'] ?? 'Branch Actions',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                  ),
                  title: const Text('Edit Details', style: TextStyle(fontWeight: FontWeight.w500)),
                  onTap: () { // Fixed here: changed from onPressed to onTap
                    Navigator.pop(context);
                    _goToEditBranch(branch);
                  },
                ),
                const Divider(height: 1, indent: 60),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  ),
                  title: const Text('Delete Branch', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
                  onTap: () { // Fixed here: changed from onPressed to onTap
                    Navigator.pop(context);
                    _confirmDelete(branch);
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> branch) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Branch'),
        content: Text('Are you sure you want to delete "${branch['name']}"? This action cannot be undone.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final response = await _apiService.deleteBranch(branch['_id']);
      if (!mounted) return;

      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Branch deleted successfully'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
        _loadBranches();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Failed to delete branch'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Branches',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, letterSpacing: -0.5),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey[100], height: 1),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: _goToAddBranch,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Branch', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadBranches,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[800], fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loadBranches,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    child: const Text('Retry', style: TextStyle(color: Colors.white)),
                  )
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (_branches.isEmpty) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.account_tree_outlined, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'No branches found',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap the button below to register your first branch.',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88), 
      itemCount: _branches.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final branch = _branches[index];
        final addressParts = [
          branch['address'],
          branch['city'],
          branch['state'],
        ].where((e) => e != null && e.toString().isNotEmpty).join(', ');

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () => _showActionOptions(branch), // Tap anywhere to bring up sleek menu
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.store_mall_directory, 
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  title: Text(
                    branch['name'] ?? 'Unnamed Branch',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold, 
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Text(
                      addressParts.isNotEmpty ? addressParts : 'No address provided',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded, 
                    color: Colors.grey[400],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}