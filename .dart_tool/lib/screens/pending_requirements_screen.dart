// screens/pending_requirements_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class PendingRequirementsScreen extends StatefulWidget {
  const PendingRequirementsScreen({super.key});

  @override
  State<PendingRequirementsScreen> createState() => _PendingRequirementsScreenState();
}

class _PendingRequirementsScreenState extends State<PendingRequirementsScreen> {
  List<Map<String, dynamic>> _requirements = [];
  bool _isLoading = true;
  String? _error;

  String _selectedCategory = 'all'; // all | gold | diamond | polki
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRequirements();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRequirements() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // NOTE: category is intentionally NOT sent to the backend anymore.
      // The backend filter only checks the structured gold/diamond/polki
      // fields, which are usually left blank (e.g. requirement:
      // "diamond earing" with diamond: ""). We fetch everything and detect
      // the category ourselves from the requirement text — see
      // _detectCategories() below.
      final response = await ApiService().getPendingRequirements(
        search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      );

      if (response['success'] == true) {
        final data = response['data'] as List? ?? [];
        setState(() {
          _requirements = data.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response['message'] ?? 'Failed to load requirements';
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

  Future<void> _markAvailable(Map<String, dynamic> item) async {
    final customerId = item['customerId']?.toString();
    final visitNumber = item['visitNumber'];
    if (customerId == null || visitNumber == null) return;

    // Show contact info FIRST so staff has it before the item disappears
    // from the list — the whole point of this screen is "who do I call".
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Mark as Available'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${item['requirement'] ?? ''}" is now in stock for:',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Text(
              item['name']?.toString() ?? 'Unknown Customer',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 6),
            if ((item['phone']?.toString() ?? '').isNotEmpty)
              _contactRow(Icons.phone, item['phone'].toString()),
            if ((item['email']?.toString() ?? '').isNotEmpty)
              _contactRow(Icons.email, item['email'].toString()),
            const SizedBox(height: 12),
            const Text(
              'Marking this available will move it out of the pending list. Make sure to contact the customer.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
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

    if (proceed != true || !mounted) return;

    try {
      final visitNum = visitNumber is int ? visitNumber : int.tryParse(visitNumber.toString()) ?? 0;
      final response = await ApiService().fulfillRequirement(customerId, visitNum);

      if (response['success'] == true) {
        // ✅ Re-fetch from the server instead of just removing the row
        // locally. This is a deliberate choice over an "optimistic" local
        // removeWhere(): if the backend didn't actually persist
        // requirementStatus (e.g. a save bug), the item will still show up
        // here after refresh — which is what we WANT, so a silent backend
        // failure doesn't get masked as "it worked" in the UI.
        await _loadRequirements();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Marked available. Don\'t forget to contact ${item['name'] ?? 'the customer'}!'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${response['message'] ?? 'Failed to update'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Detects gold / diamond / polki from a requirement item. Prefers the
  // structured fields if staff actually filled them in, but falls back to
  // scanning the free-text requirement itself — e.g. "diamond earing" or
  // "gold chain 22k" — so filtering/tags work even when those fields are
  // left blank (the common case).
  static const Map<String, List<String>> _categoryKeywords = {
    'gold': ['gold', 'sona', 'sone'],
    'diamond': ['diamond', 'diamonds', 'heera', 'solitaire'],
    'polki': ['polki'],
  };

  Set<String> _detectCategories(Map<String, dynamic> item) {
    final detected = <String>{};

    final structured = item['category'] as Map<String, dynamic>? ?? {};
    for (final cat in _categoryKeywords.keys) {
      if ((structured[cat] ?? '').toString().trim().isNotEmpty) {
        detected.add(cat);
      }
    }

    final text = (item['requirement']?.toString() ?? '').toLowerCase();
    _categoryKeywords.forEach((cat, keywords) {
      if (keywords.any((kw) => text.contains(kw))) {
        detected.add(cat);
      }
    });

    return detected;
  }

  List<Map<String, dynamic>> get _visibleRequirements {
    if (_selectedCategory == 'all') return _requirements;
    return _requirements
        .where((item) => _detectCategories(item).contains(_selectedCategory))
        .toList();
  }

  Widget _contactRow(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: InkWell(
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: value));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Copied: $value'), duration: const Duration(seconds: 1)),
            );
          }
        },
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(value, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            const Icon(Icons.copy, size: 14, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Pending Requirements', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadRequirements,
        color: AppColors.primary,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search requirement or customer...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onSubmitted: (_) => _loadRequirements(),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _categoryChip('all', 'All'),
                        _categoryChip('gold', 'Gold'),
                        _categoryChip('diamond', 'Diamond'),
                        _categoryChip('polki', 'Polki'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _categoryChip(String value, String label) {
    final selected = _selectedCategory == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: AppColors.primary.withOpacity(0.15),
        onSelected: (_) {
          // Purely local now — _visibleRequirements() re-filters the
          // already-fetched list, no need to re-hit the API.
          setState(() => _selectedCategory = value);
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 40, color: Colors.red.withOpacity(0.7)),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _loadRequirements, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    final visible = _visibleRequirements;

    if (visible.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.textSecondary.withOpacity(0.35)),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _selectedCategory == 'all'
                  ? 'No pending requirements'
                  : 'No pending ${_selectedCategory} requirements',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: visible.length,
      itemBuilder: (context, index) {
        final item = visible[index];
        final tags = _detectCategories(item)
            .map((c) => c[0].toUpperCase() + c.substring(1))
            .toList();

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item['name']?.toString() ?? 'Unknown Customer',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                  if (item['branch'] != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item['branch'] is Map ? (item['branch']['name'] ?? '') : item['branch'].toString(),
                        style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                item['requirement']?.toString() ?? '',
                style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              ),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: tags.map((t) => Chip(
                    label: Text(t, style: const TextStyle(fontSize: 11)),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    backgroundColor: Colors.grey.shade100,
                  )).toList(),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  if ((item['phone']?.toString() ?? '').isNotEmpty) ...[
                    const Icon(Icons.phone, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(item['phone'].toString(), style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                  ],
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _markAvailable(item),
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Mark Available'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}