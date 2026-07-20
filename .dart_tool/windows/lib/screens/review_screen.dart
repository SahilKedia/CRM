import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/review_model.dart';
import '../services/api_service.dart';

class ReviewScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const ReviewScreen({
    Key? key,
    required this.user,
  }) : super(key: key);

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  
  List<Review> _reviews = [];
  bool _isLoading = true;
  String _selectedStatus = 'all';
  String _searchQuery = '';
  Map<String, dynamic>? _stats;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadReviews();
    _loadStats();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReviews() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _apiService.getReviews(
        status: _selectedStatus,
        search: _searchQuery,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final List<dynamic> reviewsData = result['data'] ?? [];
        setState(() {
          _reviews = reviewsData.map((item) => Review.fromJson(item)).toList();
          _isLoading = false;
        });
      } else if (result['unauthorized'] == true) {
        _showUnauthorizedDialog();
        setState(() {
          _isLoading = false;
        });
      } else {
        _showErrorSnackbar(result['message'] ?? 'Failed to load reviews');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      _showErrorSnackbar('Error loading reviews: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadStats() async {
    try {
      final result = await _apiService.getReviewStats();
      if (result['success'] == true && mounted) {
        setState(() {
          _stats = result['data'];
        });
      }
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _searchQuery = query;
        });
        _loadReviews();
      }
    });
  }

  void _showUnauthorizedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Session Expired'),
        content: const Text('Your session has expired. Please login again.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/login');
            },
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.error,
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Customer Reviews',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              _loadReviews();
              _loadStats();
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_stats != null) _buildStatsCards(),
          _buildFilterSection(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Divider(height: 1),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator.adaptive())
                : _reviews.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _reviews.length,
                        itemBuilder: (context, index) {
                          return _buildReviewCard(_reviews[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          _buildStatCard('Total', _stats!['total']?.toString() ?? '0', AppColors.primary),
          const SizedBox(width: 8),
          _buildStatCard('Submitted', _stats!['submitted']?.toString() ?? '0', AppColors.success),
          const SizedBox(width: 8),
          _buildStatCard('Pending', _stats!['pending']?.toString() ?? '0', Colors.orange),
          const SizedBox(width: 8),
          _buildStatCard('Rating', _stats!['averageRating']?.toStringAsFixed(1) ?? '0.0', Colors.amber, isRating: true),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color, {bool isRating = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isRating) ...[
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                  const SizedBox(width: 2),
                ],
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isRating ? AppColors.textPrimary : color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    final statuses = [
      {'value': 'all', 'label': 'All'},
      {'value': 'submitted', 'label': 'Submitted'},
      {'value': 'pending', 'label': 'Pending'},
      {'value': 'expired', 'label': 'Expired'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, size: 22, color: AppColors.textSecondary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: statuses.map((status) {
              final isSelected = _selectedStatus == status['value'];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(status['label']!),
                  selected: isSelected,
                  selectedColor: AppColors.primary.withOpacity(0.15),
                  backgroundColor: AppColors.surface,
                  labelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  onSelected: (bool selected) {
                    if (selected) {
                      setState(() {
                        _selectedStatus = status['value']!;
                      });
                      _loadReviews();
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewCard(Review review) {
    final statusColor = _getStatusColor(review.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border.withOpacity(0.7), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primary.withOpacity(0.08),
                  child: Text(
                    review.customerName.isNotEmpty ? review.customerName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.customerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (review.customerEmail != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          review.customerEmail!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    review.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: List.generate(5, (index) {
                return Icon(
                  index < review.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: Colors.amber,
                  size: 22,
                );
              }),
            ),
            if (review.comments.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border.withOpacity(0.4)),
                ),
                child: Text(
                  review.comments,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.storefront_rounded, size: 15, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            review.branch,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(review.submittedAt ?? review.createdAt),
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _showStatusUpdateDialog(review),
                      color: AppColors.primary,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _showDeleteConfirmation(review),
                      color: AppColors.error,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.rate_review_outlined,
                size: 48,
                color: AppColors.textSecondary.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Reviews Found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try resetting your search parameter queries or selected status filters.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'submitted':
        return AppColors.success;
      case 'pending':
        return Colors.orange;
      case 'expired':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _showStatusUpdateDialog(Review review) {
    String selectedStatus = review.status;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Update Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: ['submitted', 'pending', 'expired'].map((status) {
                return RadioListTile<String>(
                  title: Text(status.toUpperCase()[0] + status.substring(1)),
                  value: status,
                  groupValue: selectedStatus,
                  activeColor: _getStatusColor(status),
                  onChanged: (value) {
                    setStateDialog(() {
                      selectedStatus = value!;
                    });
                  },
                );
              }).toList(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _updateStatus(review, selectedStatus);
                },
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Update'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _updateStatus(Review review, String newStatus) async {
    try {
      final result = await _apiService.updateReviewStatus(review.id, newStatus);
      if (result['success'] == true) {
        _showSuccessSnackbar('Status updated successfully');
        _loadReviews();
        _loadStats();
      } else {
        _showErrorSnackbar(result['message'] ?? 'Failed to update status');
      }
    } catch (e) {
      _showErrorSnackbar('Error updating status: $e');
    }
  }

  void _showDeleteConfirmation(Review review) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Review', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete the review from ${review.customerName}? This action cannot be undone.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteReview(review);
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deleteReview(Review review) async {
    try {
      final result = await _apiService.deleteReview(review.id);
      if (result['success'] == true) {
        _showSuccessSnackbar('Review deleted successfully');
        _loadReviews();
        _loadStats();
      } else {
        _showErrorSnackbar(result['message'] ?? 'Failed to delete review');
      }
    } catch (e) {
      _showErrorSnackbar('Error deleting review: $e');
    }
  }
}