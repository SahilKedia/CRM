import 'package:flutter/material.dart';
// ⚠️ PACKAGE SWAP: use `excel_plus` instead of `excel` for image embedding.
import 'package:excel_plus/excel_plus.dart' hide Border;
import 'package:excel_plus/excel_plus.dart' as xls show Border, BorderStyle;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'add_customer_screen.dart';

// ------------------------------------------------------------
// ENUMS & HELPERS
// ------------------------------------------------------------
enum ReportType { today, thisWeek, thisMonth, custom }

extension ReportTypeExtension on ReportType {
  String get label {
    switch (this) {
      case ReportType.today:
        return 'Today';
      case ReportType.thisWeek:
        return 'This Week';
      case ReportType.thisMonth:
        return 'This Month';
      case ReportType.custom:
        return 'Custom';
    }
  }

  IconData get icon {
    switch (this) {
      case ReportType.today:
        return Icons.today_rounded;
      case ReportType.thisWeek:
        return Icons.view_week_rounded;
      case ReportType.thisMonth:
        return Icons.calendar_month_rounded;
      case ReportType.custom:
        return Icons.edit_calendar_rounded;
    }
  }
}

// ------------------------------------------------------------
// MAIN SCREEN
// ------------------------------------------------------------
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  // ------------------------------------------------------------------
  // State Variables
  // ------------------------------------------------------------------
  bool _isLoading = true;
  bool _isExporting = false;
  String _exportStatus = '';
  bool _isExportingSale = false;
  String _saleExportStatus = '';

  List<Map<String, dynamic>> _allCustomers = [];
  List<Map<String, dynamic>> _filteredCustomers = [];
  List<Map<String, dynamic>> _employees = [];

  // Filter state
  ReportType _reportType = ReportType.today;
  DateTimeRange? _dateRange;
  String? _filterConclusion;
  String? _filterEmployee;

  // Search
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  // ------------------------------------------------------------------
  // Lifecycle
  // ------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _setDefaultDateRange();
    _fetchInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------
  // Data Fetching
  // ------------------------------------------------------------------
  Future<void> _fetchInitialData() async {
    await Future.wait([_fetchCustomers(), _fetchEmployees()]);
    _applyFilters();
  }

  Future<void> _fetchCustomers() async {
    try {
      final api = ApiService();
      final response = await api.getCustomers();
      if (response["success"] == true) {
        setState(() {
          _allCustomers = List<Map<String, dynamic>>.from(response["data"]);
        });
      }
    } catch (e) {
      debugPrint('Error fetching customers: $e');
    }
  }

  Future<void> _fetchEmployees() async {
    try {
      final api = ApiService();
      final response = await api.getEmployees();
      if (response["success"] == true) {
        setState(() {
          _employees = List<Map<String, dynamic>>.from(response["data"]);
        });
      }
    } catch (e) {
      debugPrint('Error fetching employees: $e');
    }
  }

  // ------------------------------------------------------------------
  // Date Range Helpers
  // ------------------------------------------------------------------
  void _setDefaultDateRange() {
    final now = DateTime.now();
    switch (_reportType) {
      case ReportType.today:
        _dateRange = DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
        break;
      case ReportType.thisWeek:
        final start = now.subtract(Duration(days: now.weekday - 1));
        _dateRange = DateTimeRange(
          start: DateTime(start.year, start.month, start.day),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
        break;
      case ReportType.thisMonth:
        _dateRange = DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
        break;
      case ReportType.custom:
        // keep existing or set to today
        break;
    }
  }

  Future<void> _pickCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    if (picked != null) {
      setState(() {
        _dateRange = picked;
        _reportType = ReportType.custom;
        _applyFilters();
      });
    }
  }

  // ------------------------------------------------------------------
  // Filtering Logic
  // ------------------------------------------------------------------
  void _applyFilters() {
    setState(() {
      _isLoading = true;
    });

    final query = _searchController.text.toLowerCase();
    final dateRange = _dateRange;

    // Filter customers by date range (must have at least one visit in range)
    List<Map<String, dynamic>> filtered = _allCustomers.where((customer) {
      final visits = customer["visits"] as List? ?? [];
      final hasVisitInRange = visits.any((visit) {
        final visitDate = visit["visitDate"];
        if (visitDate == null) return false;
        try {
          final date = DateTime.parse(visitDate.toString());
          return date.isAfter(dateRange!.start.subtract(const Duration(seconds: 1))) &&
              date.isBefore(dateRange.end.add(const Duration(seconds: 1)));
        } catch (_) {
          return false;
        }
      });
      return hasVisitInRange;
    }).toList();

    if (_filterConclusion != null && _filterConclusion!.isNotEmpty) {
      final wanted = _filterConclusion!.trim().toLowerCase();
      filtered = filtered.where((c) {
        final visits = c["visits"] as List? ?? [];
        return visits.any((v) => (v["conclusion"]?.toString() ?? '').trim().toLowerCase() == wanted);
      }).toList();
    }

    if (_filterEmployee != null && _filterEmployee!.isNotEmpty) {
      filtered = filtered.where((c) {
        final assigned = c["assignedTo"];
        if (assigned == null) return false;
        final name = assigned is Map ? assigned["name"]?.toString() : assigned.toString();
        return name == _filterEmployee;
      }).toList();
    }

    // Search
    if (query.isNotEmpty) {
      filtered = filtered.where((customer) {
        final name = (customer["name"] ?? "").toString().toLowerCase();
        final phone = (customer["phone"] ?? "").toString().toLowerCase();
        final email = (customer["email"] ?? "").toString().toLowerCase();
        final address = (customer["address"] ?? "").toString().toLowerCase();
        return name.contains(query) ||
            phone.contains(query) ||
            email.contains(query) ||
            address.contains(query);
      }).toList();
    }

    setState(() {
      _filteredCustomers = filtered;
      _isLoading = false;
    });
  }

  // ------------------------------------------------------------------
  // UI Helpers
  // ------------------------------------------------------------------
  Color _getStatusColor(String status) {
    switch (status) {
      case "Active":
        return Colors.green;
      case "Inactive":
        return Colors.red;
      case "Lead":
        return Colors.orange;
      case "Prospect":
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Color _getConclusionColor(String conclusion) {
    switch (conclusion) {
      case "Sold":
        return Colors.green;
      case "Shortlisted":
        return Colors.orange;
      case "Just See":
        return Colors.blue;
      case "On Order":
        return Colors.purple;
      case "On Approval":
        return Colors.teal;
      case "Pending":
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return "N/A";
    return DateFormat('dd-MM-yyyy').format(date);
  }

  String _formatDateTime(dynamic dateString) {
    try {
      if (dateString == null) return "N/A";
      final date = DateTime.parse(dateString.toString());
      return DateFormat('dd-MM-yyyy HH:mm').format(date);
    } catch (_) {
      return dateString.toString();
    }
  }

  // ------------------------------------------------------------------
  // Export to Excel
  // ------------------------------------------------------------------
  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      if (await Permission.photos.isDenied) {
        if (await Permission.photos.request().isGranted) return true;
      }
      if (await Permission.manageExternalStorage.isDenied) {
        if (await Permission.manageExternalStorage.request().isGranted) return true;
      }
      if (await Permission.storage.isDenied) {
        if (await Permission.storage.request().isGranted) return true;
      }
      return await Permission.storage.isGranted ||
          await Permission.manageExternalStorage.isGranted ||
          await Permission.photos.isGranted;
    } else if (Platform.isIOS) {
      return await Permission.photos.request().isGranted;
    }
    return true;
  }

  Future<String?> _selectFolder() async {
    String? selectedPath;
    String defaultPath = await _getDefaultSavePath();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.folder_open, color: AppColors.primary),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Select Download Location',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose where to save the Excel file:'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.folder, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Default: $defaultPath',
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () async {
                final dir = await FilePicker.platform.getDirectoryPath();
                if (dir != null && dir.isNotEmpty) {
                  selectedPath = dir;
                  Navigator.pop(ctx);
                } else {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('No folder selected. Using default.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  selectedPath = defaultPath;
                  Navigator.pop(ctx);
                }
              },
              icon: const Icon(Icons.folder),
              label: const Text('Browse Folders'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                selectedPath = defaultPath;
                Navigator.pop(ctx);
              },
              child: const Text('Use Default Location'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    return selectedPath;
  }

  Future<String> _getDefaultSavePath() async {
    if (Platform.isAndroid) {
      final dir = await getExternalStorageDirectory();
      if (dir != null) {
        final parts = dir.path.split('/');
        if (parts.length >= 4) {
          parts.removeLast();
          parts.removeLast();
          parts.removeLast();
          parts.add('Download');
          return parts.join('/');
        }
      }
    } else if (Platform.isIOS) {
      return (await getApplicationDocumentsDirectory()).path;
    }
    return (await getApplicationDocumentsDirectory()).path;
  }

  String _normalizeConclusion(String conclusion) => conclusion.trim().toLowerCase();

  /// Row background colour per conclusion — matches your printed report's colour key.
  ExcelColor _getConclusionExcelColor(String conclusion) {
    final c = _normalizeConclusion(conclusion);
    if (c.contains('sold')) return ExcelColor.fromHexString('#FFFF00');
    if (c.contains('shortlist')) return ExcelColor.fromHexString('#C6E0B4');
    if (c.contains('just see') || c.contains('justsee')) {
      return ExcelColor.fromHexString('#BDD7EE');
    }
    if (c.contains('order')) return ExcelColor.fromHexString('#D9C2E9');
    if (c.contains('requirement') || c.contains('pending')) {
      return ExcelColor.fromHexString('#D9D9D9');
    }
    if (c.contains('approval')) return ExcelColor.fromHexString('#F4B183');
    return ExcelColor.fromHexString('#FFFFFF');
  }

  /// Which of the six status columns (SOLD/SHORTLIST/JUST SEE/ON ORDER/
  /// REQUIREMENT/APPROVAL) a conclusion value should be written into.
  /// Column indices refer to the layout built in _exportToExcel below.
  /// ✅ UPDATED: Gold/Diamond/Polki each now occupy 2 columns (see the
  /// column-layout constants), so everything after them shifted right —
  /// status columns now start at 12 instead of 9.
  int _conclusionColumnIndex(String conclusion) {
    final c = _normalizeConclusion(conclusion);
    if (c.contains('sold')) return 12;
    if (c.contains('shortlist')) return 13;
    if (c.contains('just see') || c.contains('justsee')) return 14;
    if (c.contains('order')) return 15;
    if (c.contains('requirement') || c.contains('pending')) return 16;
    if (c.contains('approval')) return 17;
    return -1;
  }

  /// ✅ NEW: true for any of the 6 physical columns that make up the
  /// Gold / Diamond / Polki image pairs (6,7 / 8,9 / 10,11).
  bool _isImageColumn(int col) =>
      col == _colGold ||
      col == _colGold + 1 ||
      col == _colDiamond ||
      col == _colDiamond + 1 ||
      col == _colPolki ||
      col == _colPolki + 1;

  /// ✅ NEW: true for the second (right-hand) column of an image pair —
  /// used so we can skip drawing a border between the two sub-columns
  /// of the same category.
  bool _isRightOfImagePair(int col) =>
      col == _colGold + 1 || col == _colDiamond + 1 || col == _colPolki + 1;

  String _titleCase(String input) {
    if (input.trim().isEmpty) return '';
    return input.trim().split(RegExp(r'\s+')).map((w) {
      if (w.isEmpty) return w;
      return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
    }).join(' ');
  }

  /// `whoAttend` on a visit is stored as an employee _id — resolve it to a
  /// display name using the employees already fetched for the filter bar.
  String _resolveEmployeeName(dynamic idOrName) {
    if (idOrName == null) return '';
    final idStr = idOrName.toString();
    if (idStr.isEmpty) return '';
    final match = _employees.firstWhere(
      (e) => e['_id']?.toString() == idStr,
      orElse: () => const {},
    );
    if (match.isNotEmpty && match['name'] != null) {
      return match['name'].toString();
    }
    // Fall back to the raw value in case it's already a name, not an id.
    return idStr;
  }

  String _resolveImageUrl(String raw) {
    // Reuses the same base URL as the rest of the app (AppConfig.serverUrl),
    // so it stays correct automatically if the server address ever changes.
    return ApiService.getImageUrl(raw);
  }

  /// How many stacked image-rows a category needs, given [colsPerCategory]
  /// images fit side by side within one row of that category's own columns.
  int _rowsNeededForImages(int count, {int colsPerCategory = _imageColsPerCategory}) {
    if (count <= 0) return 1;
    return (count / colsPerCategory).ceil();
  }

  /// ✅ FIXED: embeds ALL images from [imageUrls] as a small grid confined
  /// to THIS customer's own row-block — [colsPerCategory] images per row,
  /// starting at [colStart]/[startRow]. Earlier versions either only
  /// embedded the first image, or stacked extra images at startRow + i,
  /// which spilled into the NEXT customer's row (excel_plus's insertImage
  /// has no per-image offset inside a single cell, so "stacking" via
  /// row + i actually meant "leaking into other rows"). Now the caller
  /// reserves enough real rows for this visit via _rowsNeededForImages
  /// BEFORE moving on to the next customer, so a grid of images can live
  /// entirely inside this customer's own block without ever touching
  /// another customer's data.
  Future<int> _embedImageBlock({
    required Sheet sheet,
    required int colStart,
    required int startRow,
    required List? imageUrls,
    int colsPerCategory = _imageColsPerCategory,
    int size = 70,
  }) async {
    if (imageUrls == null || imageUrls.isEmpty) return 0;
    int embedded = 0;

    for (int i = 0; i < imageUrls.length; i++) {
      final raw = imageUrls[i]?.toString() ?? '';
      if (raw.isEmpty) continue;

      final url = _resolveImageUrl(raw);
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.hasScheme) {
        debugPrint('Skipping image — not a valid absolute URL: "$raw" '
            '(resolved: "$url").');
        continue;
      }

      try {
        final response = await http.get(uri).timeout(const Duration(seconds: 15));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          final int rowOffset = i ~/ colsPerCategory;
          final int colOffset = i % colsPerCategory;
          final int targetRow = startRow + rowOffset; // stays within THIS visit's block
          final int targetCol = colStart + colOffset;  // stays within THIS category's columns

          debugPrint('Embedding image $i at row $targetRow, col $targetCol');

          sheet.insertImage(
            response.bodyBytes,
            anchor: CellIndex.indexByColumnRow(
              columnIndex: targetCol,
              rowIndex: targetRow,
            ),
            width: size,
            height: size,
          );
          embedded++;
        } else {
          debugPrint('Image fetch failed for $url — HTTP ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('Failed to embed image from $url: $e');
      }
    }

    return embedded;
  }

  /// Embeds a list of image URLs into a grid (default 4 per row) starting
  /// at [startRow]/[startCol]. Used only by the Sale Report export, where
  /// we show ALL sold images per category, not just the first one.
  Future<Map<String, int>> _embedImageGrid({
    required Sheet sheet,
    required List<String> imageUrls,
    required int startRow,
    int startCol = 1,
    int imagesPerRow = 4,
    int size = 85,
  }) async {
    int attempted = 0;
    int embedded = 0;

    for (int i = 0; i < imageUrls.length; i++) {
      final raw = imageUrls[i];
      if (raw.isEmpty) continue;
      attempted++;

      final url = _resolveImageUrl(raw);
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.hasScheme) {
        debugPrint('Sale report: skipping invalid image URL "$raw"');
        continue;
      }

      final row = startRow + (i ~/ imagesPerRow);
      final col = startCol + (i % imagesPerRow);

      try {
        final response = await http.get(uri).timeout(const Duration(seconds: 15));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          sheet.insertImage(
            response.bodyBytes,
            anchor: CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
            width: size.toInt(),
            height: size.toInt(),
          );
          embedded++;
        } else {
          debugPrint('Sale report: image fetch failed for $url — HTTP ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('Sale report: failed to embed image from $url: $e');
      }
    }

    return {'attempted': attempted, 'embedded': embedded};
  }

  // --------------------- CORRECTED COLUMN LAYOUT ---------------------
  // ✅ UPDATED: Gold / Diamond / Polki each now occupy 2 physical columns
  // (so multiple images can sit side by side instead of only 1 per
  // category), everything after them is shifted right accordingly.
  static const int _colDate = 0;
  static const int _colSerial = 1;
  static const int _colName = 2;
  static const int _colPhone = 3;
  static const int _colAddress = 4;
  static const int _colPurpose = 5;
  static const int _colGold = 6;      // spans columns 6-7
  static const int _colDiamond = 8;   // spans columns 8-9
  static const int _colPolki = 10;    // spans columns 10-11
  static const int _imageColsPerCategory = 2;
  // 12..17 are the status columns (SOLD/SHORTLIST/JUST SEE/ON ORDER/REQUIREMENT/APPROVAL)
  static const int _colWhoAttend = 18;
  static const int _colHelper = 19;
  static const int _colMedia = 20;
  static const int _colConclusion = 21;
  static const int _totalColumns = 22;    // indices 0..21

  /// Builds the workbook in the same layout as your printed register:
  /// rows grouped under a date header, Gold/Diamond/Polki as image-only
  /// column-pairs (all images per category shown in a grid), the item
  /// description routed into the matching status column, the whole
  /// row-block colour-coded by conclusion, and a totals footer.
  Future<void> _exportToExcel() async {
    if (_filteredCustomers.isEmpty) {
      _showSnackBar('No data to export', Colors.orange);
      return;
    }

    setState(() {
      _isExporting = true;
      _exportStatus = 'Preparing export...';
    });

    try {
      final hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        setState(() => _isExporting = false);
        _showSnackBar('Storage permission is required to export', Colors.red);
        return;
      }

      final folder = await _selectFolder();
      if (folder == null) {
        setState(() => _isExporting = false);
        return;
      }

      final excel = Excel.createExcel();
      const sheetName = 'Customer Report';
      final Sheet sheet = excel[sheetName];
      excel.setDefaultSheet(sheetName);
      if (excel.sheets.containsKey('Sheet1') && sheetName != 'Sheet1') {
        excel.delete('Sheet1');
      }

      // ---------------- Cell border (all cells in the sheet use this) ----------------
      final cellBorder = xls.Border(
        borderStyle: xls.BorderStyle.Medium,
        borderColorHex: ExcelColor.fromHexString('#000000'),
      );

      // ---------------- Header ----------------
      final headerStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#4472C4'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        textWrapping: TextWrapping.WrapText,
        leftBorder: cellBorder,
        rightBorder: cellBorder,
        topBorder: cellBorder,
        bottomBorder: cellBorder,
      );

      // ✅ UPDATED: headers now mapped by explicit column index (since
      // Gold/Diamond/Polki each span 2 columns, header text is written to
      // the FIRST column of the pair and then merged across both).
      final headerLabels = <int, String>{
        _colDate: 'DATE',
        _colSerial: 'S.NO',
        _colName: 'CUSTOMER NAME',
        _colPhone: 'PHONE NO',
        _colAddress: 'ADDRESS',
        _colPurpose: 'PURPOSE OF VISIT',
        _colGold: 'GOLD',
        _colDiamond: 'DIAMOND',
        _colPolki: 'POLKI',
        12: 'SOLD',
        13: 'SHORTLIST',
        14: 'JUST SEE',
        15: 'ON ORDER',
        16: 'REQUIREMENT',
        17: 'APPROVAL',
        _colWhoAttend: 'WHO ATTEND',
        _colHelper: 'HELPER',
        _colMedia: 'MEDIA',
        _colConclusion: 'CONCLUSION',
      };

      headerLabels.forEach((col, label) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0),
        );
        cell.value = TextCellValue(label);
        cell.cellStyle = headerStyle;
      });

      // GOLD / DIAMOND / POLKI headers each span their 2 image columns.
      for (final start in [_colGold, _colDiamond, _colPolki]) {
        sheet.merge(
          CellIndex.indexByColumnRow(columnIndex: start, rowIndex: 0),
          CellIndex.indexByColumnRow(columnIndex: start + _imageColsPerCategory - 1, rowIndex: 0),
        );
      }
      sheet.setRowHeight(0, 30);

      // ---------------- Column widths (updated indices) ----------------
      final columnWidths = <int, double>{
        _colDate: 12,
        _colSerial: 6,
        _colName: 20,
        _colPhone: 15,
        _colAddress: 38,
        _colPurpose: 22,
        _colGold: 16, _colGold + 1: 16,
        _colDiamond: 16, _colDiamond + 1: 16,
        _colPolki: 16, _colPolki + 1: 16,
        12: 13,  // SOLD
        13: 13,  // SHORTLIST
        14: 13,  // JUST SEE
        15: 13,  // ON ORDER
        16: 14,  // REQUIREMENT
        17: 13,  // APPROVAL
        _colWhoAttend: 15,
        _colHelper: 12,
        _colMedia: 12,
        _colConclusion: 15,
      };
      columnWidths.forEach((col, width) => sheet.setColumnWidth(col, width));

      // ---------------- Group visits by date ----------------
      // key: yyyy-MM-dd, value: list of {customer, visit}
      final Map<String, List<Map<String, dynamic>>> visitsByDate = {};

      for (final customer in _filteredCustomers) {
        final visits = customer['visits'] as List? ?? [];
        for (final visit in visits) {
          final d = visit['visitDate'];
          if (d == null || _dateRange == null) continue;
          DateTime date;
          try {
            date = DateTime.parse(d.toString());
          } catch (_) {
            continue;
          }
          final inRange = date.isAfter(
                  _dateRange!.start.subtract(const Duration(seconds: 1))) &&
              date.isBefore(_dateRange!.end.add(const Duration(seconds: 1)));
          if (!inRange) continue;

          final dateKey = DateFormat('yyyy-MM-dd').format(date);
          visitsByDate.putIfAbsent(dateKey, () => []).add({
            'customer': customer,
            'visit': visit,
          });
        }
      }

      final sortedDateKeys = visitsByDate.keys.toList()..sort();

      int rowIndex = 1;
      int serial = 1;
      int soldCount = 0;
      int totalVisitsExported = 0;
      int imagesAttempted = 0;
      int imagesEmbedded = 0;
      final Set<String> customerIds = {};

      final dateHeaderStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
        leftBorder: cellBorder,
        rightBorder: cellBorder,
        topBorder: cellBorder,
        bottomBorder: cellBorder,
      );

      for (final dateKey in sortedDateKeys) {
        final entries = visitsByDate[dateKey]!;

        // ---- Date separator row, merged across the whole width ----
        sheet.merge(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
          CellIndex.indexByColumnRow(columnIndex: _totalColumns - 1, rowIndex: rowIndex),
        );
        final dateCell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
        );
        dateCell.value = TextCellValue(_formatDate(DateTime.parse(dateKey)));
        dateCell.cellStyle = dateHeaderStyle;
        sheet.setRowHeight(rowIndex, 18);
        rowIndex++;

        for (final entry in entries) {
          final customer = entry['customer'] as Map<String, dynamic>;
          final visit = entry['visit'] as Map<String, dynamic>;

          setState(() {
            _exportStatus =
                'Exporting ${customer['name'] ?? ''} (${totalVisitsExported + 1})...';
          });

          final customerId = customer['_id']?.toString() ?? customer['name']?.toString() ?? '';
          if (customerId.isNotEmpty) customerIds.add(customerId);

          final conclusionRaw = (visit['conclusion']?.toString() ?? '').trim();
          final statusCol = _conclusionColumnIndex(conclusionRaw);
          final rowColor = _getConclusionExcelColor(conclusionRaw);
          if (_normalizeConclusion(conclusionRaw).contains('sold')) soldCount++;

          // ---- ✅ How many image-rows does this visit need? ----
          final goldList = visit['goldImages'] as List? ?? [];
          final diamondList = visit['diamondImages'] as List? ?? [];
          final polkiList = visit['polkiImages'] as List? ?? [];

          final goldRows = _rowsNeededForImages(goldList.length);
          final diamondRows = _rowsNeededForImages(diamondList.length);
          final polkiRows = _rowsNeededForImages(polkiList.length);
          final rowsNeeded = [goldRows, diamondRows, polkiRows].reduce((a, b) => a > b ? a : b);

          // ✅ Border logic for a clean block:
          //  - Image columns (Gold/Diamond/Polki pairs): border only on the
          //    OUTER edge of the whole stacked block for that category — no
          //    line between stacked image rows, and no line between the two
          //    sub-columns of the same category (so it reads as one box).
          //  - Every other column: fully merged into a single cell for the
          //    whole block, so it only ever has ONE outer border, same as
          //    Name/Phone/Address already look.
       CellStyle blockStyle({
  ExcelColor? bg,
  required bool top,
 required bool bottom,
 required bool left,
 required bool right,
}) {
  return CellStyle(
    verticalAlign: VerticalAlign.Center,
    textWrapping: TextWrapping.WrapText,
    backgroundColorHex: bg ?? ExcelColor.fromHexString('#FFFFFF'),
    leftBorder: left ? cellBorder : null,
    rightBorder: right ? cellBorder : null,
    topBorder: top ? cellBorder : null,
    bottomBorder: bottom ? cellBorder : null,
  );
}

          // r = physical row offset within this visit's block (0-based)
          CellStyle styleFor(int col, int r) {
            final bg = col >= _colGold ? rowColor : null;

            if (_isImageColumn(col)) {
              return blockStyle(
                bg: bg,
                top: r == 0,
                bottom: r == rowsNeeded - 1,
                left: !_isRightOfImagePair(col),
                right: _isRightOfImagePair(col),
              );
            }

            // Non-image columns are merged into one cell for the block —
            // a single clean outer border is enough.
            return blockStyle(bg: bg, top: true, bottom: true, left: true, right: true);
          }

          // ---- Row height for the whole block ----
          final address = customer['address']?.toString() ?? '';
          final purpose = visit['purposeOfVisit']?.toString() ?? '';
          final longest = address.length > purpose.length ? address : purpose;
          final estimatedLines = (longest.length / 32).ceil().clamp(1, 8);
          final textHeight = (estimatedLines * 15).toDouble();

          const double imageRowHeight = 78.0; // ~70px image + padding
          final totalImageHeight = rowsNeeded * imageRowHeight;
          final perRowHeight =
              (totalImageHeight > textHeight ? totalImageHeight : textHeight) / rowsNeeded;

          for (int r = 0; r < rowsNeeded; r++) {
            sheet.setRowHeight(rowIndex + r, perRowHeight.clamp(20, 200));
          }

          debugPrint('Row $rowIndex uses $rowsNeeded row(s) '
              '(gold: ${goldList.length}, diamond: ${diamondList.length}, polki: ${polkiList.length})');

          // ---- ✅ Style ONLY the image columns per physical row — these
          //         can't be merged because insertImage needs a real,
          //         individual cell to anchor each image to. ----
          for (int r = 0; r < rowsNeeded; r++) {
            for (int col = 0; col < _totalColumns; col++) {
              if (_isImageColumn(col)) {
                sheet
                    .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex + r))
                    .cellStyle = styleFor(col, r);
              }
            }
          }

          // ---- ✅ Every non-image column: merged into ONE cell across the
          //         whole block (even when empty), so it can never show an
          //         internal grid line. ----
          void mergeColumn(int col, String value) {
            final cell = sheet.cell(
              CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex),
            );
            if (value.isNotEmpty) {
              cell.value = TextCellValue(value);
            }
            // Reapply style after setting value — some excel_plus versions
            // reset the cell's style when .value is assigned afterwards.
            cell.cellStyle = styleFor(col, 0);
            if (rowsNeeded > 1) {
              sheet.merge(
                CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex),
                CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex + rowsNeeded - 1),
              );
            }
          }

          final columnValues = <int, String>{
            _colSerial: serial.toString(),
            _colName: customer['name']?.toString() ?? '',
            _colPhone: customer['phone']?.toString() ?? '',
            _colAddress: customer['address']?.toString() ?? '',
            _colPurpose: visit['purposeOfVisit']?.toString() ?? '',
            _colWhoAttend: _resolveEmployeeName(visit['whoAttend']),
            _colHelper: visit['helper']?.toString() ?? '',
            _colConclusion: _titleCase(conclusionRaw),
            if (statusCol != -1) statusCol: visit['purposeOfVisit']?.toString() ?? '',
          };

          for (int col = 0; col < _totalColumns; col++) {
            if (_isImageColumn(col)) continue;
            mergeColumn(col, columnValues[col] ?? '');
          }

          // ---- ✅ Embed ALL Gold / Diamond / Polki images, as a grid,
          //         entirely within this visit's own row-block ----
          imagesAttempted += goldList.length + diamondList.length + polkiList.length;

          imagesEmbedded += await _embedImageBlock(
            sheet: sheet,
            colStart: _colGold,
            startRow: rowIndex,
            imageUrls: goldList,
          );
          imagesEmbedded += await _embedImageBlock(
            sheet: sheet,
            colStart: _colDiamond,
            startRow: rowIndex,
            imageUrls: diamondList,
          );
          imagesEmbedded += await _embedImageBlock(
            sheet: sheet,
            colStart: _colPolki,
            startRow: rowIndex,
            imageUrls: polkiList,
          );

          rowIndex += rowsNeeded; // ✅ advance past the WHOLE block — next customer starts clean
          serial++;
          totalVisitsExported++;
        }
      }

      // ---------------- Footer totals ----------------
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
        CellIndex.indexByColumnRow(columnIndex: _totalColumns - 1, rowIndex: rowIndex),
      );
      final totalCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
      );
      totalCell.value = TextCellValue('TOTAL CUSTOMER : ${customerIds.length}');
      totalCell.cellStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        backgroundColorHex: ExcelColor.fromHexString('#FF0000'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        leftBorder: cellBorder,
        rightBorder: cellBorder,
        topBorder: cellBorder,
        bottomBorder: cellBorder,
      );
      sheet.setRowHeight(rowIndex, 18);
      rowIndex++;

      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
        CellIndex.indexByColumnRow(columnIndex: _totalColumns - 1, rowIndex: rowIndex),
      );
      final saleCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
      );
      saleCell.value = TextCellValue('SALE : $soldCount');
      saleCell.cellStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        backgroundColorHex: ExcelColor.fromHexString('#FFFF00'),
        leftBorder: cellBorder,
        rightBorder: cellBorder,
        topBorder: cellBorder,
        bottomBorder: cellBorder,
      );
      sheet.setRowHeight(rowIndex, 18);
      rowIndex++;

      setState(() => _exportStatus = 'Saving file...');

      final fileBytes = excel.save();
      if (fileBytes == null) {
        throw Exception('Failed to generate excel bytes');
      }

      final fileName =
          'Customer_Report_${DateFormat('ddMMyyyy_HHmmss').format(DateTime.now())}.xlsx';
      final filePath = '$folder/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(fileBytes);

      setState(() {
        _isExporting = false;
        _exportStatus = '';
      });

      _showExportSuccessDialog(
        filePath,
        folder,
        totalVisitsExported,
        imagesAttempted,
        imagesEmbedded,
      );
    } catch (e) {
      debugPrint('Export error: $e');
      setState(() {
        _isExporting = false;
        _exportStatus = '';
      });
      _showSnackBar('Export failed: $e', Colors.red);
    }
  }
  

  // ------------------------------------------------------------------
  // Export SALE ONLY report (grid layout: GOLD/DIAMOND/POLKI rows,
  // images in columns, grouped by date) — matches the printed
  // "SOLD ITEMS : dd-mm-yyyy" register format.
  // ------------------------------------------------------------------
  static const int _saleImagesPerRow = 4;

  Future<void> _exportSaleReport() async {
    setState(() {
      _isExportingSale = true;
      _saleExportStatus = 'Preparing sale report...';
    });

    try {
      final hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        setState(() => _isExportingSale = false);
        _showSnackBar('Storage permission is required to export', Colors.red);
        return;
      }

      // Group only SOLD visits (within the currently selected date range)
      // by date, collecting gold/diamond/polki image URLs separately.
      final Map<String, Map<String, List<String>>> soldByDate = {};

      for (final customer in _allCustomers) {
        final visits = customer['visits'] as List? ?? [];
        for (final visit in visits) {
          final conclusion = visit['conclusion']?.toString() ?? '';
          if (!_normalizeConclusion(conclusion).contains('sold')) continue;

          final d = visit['visitDate'];
          if (d == null || _dateRange == null) continue;
          DateTime date;
          try {
            date = DateTime.parse(d.toString());
          } catch (_) {
            continue;
          }
          final inRange = date.isAfter(
                  _dateRange!.start.subtract(const Duration(seconds: 1))) &&
              date.isBefore(_dateRange!.end.add(const Duration(seconds: 1)));
          if (!inRange) continue;

          final dateKey = DateFormat('yyyy-MM-dd').format(date);
          final bucket = soldByDate.putIfAbsent(
            dateKey,
            () => {'gold': <String>[], 'diamond': <String>[], 'polki': <String>[]},
          );
          bucket['gold']!.addAll(
              ((visit['goldImages'] as List?) ?? []).map((e) => e.toString()));
          bucket['diamond']!.addAll(
              ((visit['diamondImages'] as List?) ?? []).map((e) => e.toString()));
          bucket['polki']!.addAll(
              ((visit['polkiImages'] as List?) ?? []).map((e) => e.toString()));
        }
      }

      if (soldByDate.isEmpty) {
        setState(() => _isExportingSale = false);
        _showSnackBar('No sold items found in the selected period', Colors.orange);
        return;
      }

      final folder = await _selectFolder();
      if (folder == null) {
        setState(() => _isExportingSale = false);
        return;
      }

      final excel = Excel.createExcel();
      const sheetName = 'Sale Report';
      final Sheet sheet = excel[sheetName];
      excel.setDefaultSheet(sheetName);
      if (excel.sheets.containsKey('Sheet1') && sheetName != 'Sheet1') {
        excel.delete('Sheet1');
      }

      final cellBorder = xls.Border(
        borderStyle: xls.BorderStyle.Medium,
        borderColorHex: ExcelColor.fromHexString('#000000'),
      );

      sheet.setColumnWidth(0, 14);
      for (int c = 1; c <= _saleImagesPerRow; c++) {
        sheet.setColumnWidth(c, 16);
      }

      final dateHeaderStyle = CellStyle(
        bold: true,
        fontColorHex: ExcelColor.fromHexString('#FF0000'),
        backgroundColorHex: ExcelColor.fromHexString('#BDD7EE'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        leftBorder: cellBorder,
        rightBorder: cellBorder,
        topBorder: cellBorder,
        bottomBorder: cellBorder,
      );

      final categoryLabelStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#FFFF00'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        leftBorder: cellBorder,
        rightBorder: cellBorder,
        topBorder: cellBorder,
        bottomBorder: cellBorder,
      );

      final imageCellStyle = CellStyle(
        leftBorder: cellBorder,
        rightBorder: cellBorder,
        topBorder: cellBorder,
        bottomBorder: cellBorder,
      );

      const categoryOrder = ['gold', 'diamond', 'polki'];
      const categoryLabels = {'gold': 'GOLD', 'diamond': 'DIAMOND', 'polki': 'POLKI'};
      const imageRowHeight = 95.0;

      final sortedDateKeys = soldByDate.keys.toList()..sort();
      int rowIndex = 0;
      int totalImagesAttempted = 0;
      int totalImagesEmbedded = 0;
      int totalSoldItems = 0;

      for (final dateKey in sortedDateKeys) {
        final bucket = soldByDate[dateKey]!;
        final nonEmptyCategories =
            categoryOrder.where((k) => bucket[k]!.isNotEmpty).toList();
        if (nonEmptyCategories.isEmpty) continue;

        // ---- Date header row: "SOLD ITEMS : dd-mm-yyyy" ----
        sheet.merge(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
          CellIndex.indexByColumnRow(columnIndex: _saleImagesPerRow, rowIndex: rowIndex),
        );
        final headerCell =
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
        headerCell.value =
            TextCellValue('SOLD ITEMS : ${_formatDate(DateTime.parse(dateKey))}');
        headerCell.cellStyle = dateHeaderStyle;
        sheet.setRowHeight(rowIndex, 26);
        rowIndex++;

        // ---- One block per category (GOLD / DIAMOND / POLKI) ----
        for (final catKey in nonEmptyCategories) {
          final urls = bucket[catKey]!;
          totalSoldItems += urls.length;
          final rowsNeeded = (urls.length / _saleImagesPerRow).ceil().clamp(1, 1000);

          for (int r = 0; r < rowsNeeded; r++) {
            for (int c = 0; c <= _saleImagesPerRow; c++) {
              sheet
                  .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIndex + r))
                  .cellStyle = c == 0 ? categoryLabelStyle : imageCellStyle;
            }
            sheet.setRowHeight(rowIndex + r, imageRowHeight);
          }

          if (rowsNeeded > 1) {
            sheet.merge(
              CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
              CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex + rowsNeeded - 1),
            );
          }
          final labelCell =
              sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
          labelCell.value = TextCellValue(categoryLabels[catKey]!);
          labelCell.cellStyle = categoryLabelStyle;

          setState(() {
            _saleExportStatus =
                'Embedding ${categoryLabels[catKey]} images (${urls.length})...';
          });

          final result = await _embedImageGrid(
            sheet: sheet,
            imageUrls: urls,
            startRow: rowIndex,
            startCol: 1,
            imagesPerRow: _saleImagesPerRow,
            size: 85,
          );
          totalImagesAttempted += result['attempted']!;
          totalImagesEmbedded += result['embedded']!;

          rowIndex += rowsNeeded;
        }

        rowIndex++; // spacer row between dates
      }

      setState(() => _saleExportStatus = 'Saving file...');

      final fileBytes = excel.save();
      if (fileBytes == null) throw Exception('Failed to generate excel bytes');

      final fileName =
          'Sale_Report_${DateFormat('ddMMyyyy_HHmmss').format(DateTime.now())}.xlsx';
      final filePath = '$folder/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(fileBytes);

      setState(() {
        _isExportingSale = false;
        _saleExportStatus = '';
      });

      _showSaleExportSuccessDialog(
        filePath,
        totalSoldItems,
        totalImagesAttempted,
        totalImagesEmbedded,
      );
    } catch (e) {
      debugPrint('Sale report export error: $e');
      setState(() {
        _isExportingSale = false;
        _saleExportStatus = '';
      });
      _showSnackBar('Sale report export failed: $e', Colors.red);
    }
  }

  void _showSaleExportSuccessDialog(
    String filePath,
    int totalSoldItems,
    int imagesAttempted,
    int imagesEmbedded,
  ) {
    if (!mounted) return;
    final imagesFailed = imagesAttempted - imagesEmbedded;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Sale Report Exported'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$totalSoldItems sold item(s) included.'),
            if (imagesAttempted > 0) ...[
              const SizedBox(height: 4),
              Text(
                imagesFailed == 0
                    ? '$imagesEmbedded/$imagesAttempted images embedded.'
                    : '$imagesEmbedded/$imagesAttempted images embedded — '
                        '$imagesFailed failed to load.',
                style: TextStyle(
                  fontSize: 12,
                  color: imagesFailed == 0 ? Colors.green[700] : Colors.orange[800],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text('Saved to:\n$filePath', style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  void _showExportSuccessDialog(
    String filePath,
    String folder,
    int totalVisitsExported,
    int imagesAttempted,
    int imagesEmbedded,
  ) {
    if (!mounted) return;
    final imagesFailed = imagesAttempted - imagesEmbedded;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Export Successful'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$totalVisitsExported visit(s) exported.'),
            if (imagesAttempted > 0) ...[
              const SizedBox(height: 4),
              Text(
                imagesFailed == 0
                    ? '$imagesEmbedded/$imagesAttempted images embedded.'
                    : '$imagesEmbedded/$imagesAttempted images embedded — '
                        '$imagesFailed failed to load (check the app logs for the '
                        'URL and HTTP status of each failure).',
                style: TextStyle(
                  fontSize: 12,
                  color: imagesFailed == 0 ? Colors.green[700] : Colors.orange[800],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text('Saved to:\n$filePath', style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Navigation
  // ------------------------------------------------------------------
  void _navigateToCustomerDetail(Map<String, dynamic> customer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerDetailScreen(customer: customer, employees: _employees),
      ),
    );
  }

  // ------------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FA),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // ---- FILTER BAR ----
          _buildFilterBar(),

          // ---- SUMMARY CARD ----
          _buildSummaryCard(),

          // ---- EXPORT PROGRESS ----
          if (_isExporting && _exportStatus.isNotEmpty) _buildProgressBanner(_exportStatus, AppColors.primary),
          if (_isExportingSale && _saleExportStatus.isNotEmpty)
            _buildProgressBanner(_saleExportStatus, Colors.amber.shade800),

          // ---- CUSTOMER LIST ----
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCustomers.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _fetchInitialData,
                        color: AppColors.primary,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
                          itemCount: _filteredCustomers.length,
                          itemBuilder: (ctx, index) {
                            final customer = _filteredCustomers[index];
                            final visits = customer["visits"] as List? ?? [];
                            final visitsInRange = visits.where((v) {
                              final d = v["visitDate"];
                              if (d == null || _dateRange == null) return false;
                              try {
                                final date = DateTime.parse(d.toString());
                                return date.isAfter(_dateRange!.start.subtract(const Duration(seconds: 1))) &&
                                    date.isBefore(_dateRange!.end.add(const Duration(seconds: 1)));
                              } catch (_) {
                                return false;
                              }
                            }).toList();

                            return _buildCustomerCard(customer, visitsInRange);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // AppBar
  // ------------------------------------------------------------------
PreferredSizeWidget _buildAppBar() {
  return AppBar(
    elevation: 0,
    scrolledUnderElevation: 0,
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
    titleSpacing: 8,
    title: _isSearching
        ? SizedBox(
            height: 42,
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search by name, phone, email...',
                hintStyle: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: Colors.white,
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Colors.grey.shade500,
                  size: 20,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10),
              ),
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 14.5,
              ),
              onChanged: (_) => _applyFilters(),
            ),
          )
        : const Text(
            'Customer Reports',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
    actions: [
      if (_isSearching)
        IconButton(
          tooltip: 'Close search',
          icon: const Icon(Icons.close_rounded),
          onPressed: () {
            _searchController.clear();
            setState(() => _isSearching = false);
            _applyFilters();
            FocusScope.of(context).unfocus();
          },
        )
      else ...[
        IconButton(
          tooltip: 'Search',
          icon: const Icon(Icons.search_rounded),
          onPressed: () {
            setState(() => _isSearching = true);
          },
        ),

       PopupMenuButton<String>(
  tooltip: "More",
  elevation: 8,
  color: Colors.white,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(18),
  ),
  offset: const Offset(0, 50),
  icon: Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Icon(
      Icons.more_vert_rounded,
      color: Colors.white,
      size: 20,
    ),
  ),
  onSelected: (value) {
    switch (value) {
      case "excel":
        if (!_isExporting) _exportToExcel();
        break;

      case "sale":
        if (!_isExportingSale) _exportSaleReport();
        break;
    }
  },
  itemBuilder: (context) => [

    PopupMenuItem<String>(
      value: "excel",
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: _isExporting
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.table_chart_rounded,
                    color: Colors.green.shade700,
                  ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Excel Report",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  "Export customer data",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),

    const PopupMenuDivider(),

    PopupMenuItem<String>(
      value: "sale",
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: _isExportingSale
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.photo_library_rounded,
                    color: Colors.orange.shade700,
                  ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Sale Report",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  "Export images only",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  ],
),

        const SizedBox(width: 4),
      ],
    ],
  );
}

  Widget _buildProgressBanner(String status, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      color: color.withOpacity(0.08),
      child: Row(
        children: [
          SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              status,
              style: TextStyle(fontSize: 12.5, color: color, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Filter Bar Widget
  // ------------------------------------------------------------------
  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Date range dropdown
            _filterPill(
              icon: _reportType.icon,
              color: AppColors.primary,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<ReportType>(
                  value: _reportType,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                  items: ReportType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.label),
                    );
                  }).toList(),
                  onChanged: (type) {
                    if (type != null) {
                      setState(() {
                        _reportType = type;
                        if (type == ReportType.custom) {
                          _pickCustomDateRange();
                        } else {
                          _setDefaultDateRange();
                          _applyFilters();
                        }
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Conclusion filter
            _filterPill(
              icon: Icons.label_rounded,
              color: Colors.deepPurple,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _filterConclusion,
                  hint: const Text('Conclusion', style: TextStyle(fontSize: 13)),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All')),
                    ...['Sold', 'Shortlisted', 'Just See', 'On Order', 'On Approval', 'Pending']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s))),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _filterConclusion = val;
                      _applyFilters();
                    });
                  },
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Employee filter
            _filterPill(
              icon: Icons.badge_rounded,
              color: Colors.teal,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _filterEmployee,
                  hint: const Text('Employee', style: TextStyle(fontSize: 13)),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All')),
                    ..._employees.map((e) {
                      final name = e["name"]?.toString() ?? '';
                      return DropdownMenuItem(value: name, child: Text(name));
                    }),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _filterEmployee = val;
                      _applyFilters();
                    });
                  },
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Custom date picker (visible only when custom is selected)
            if (_reportType == ReportType.custom)
              Material(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: _pickCustomDateRange,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.edit_calendar_rounded, size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          _dateRange != null
                              ? '${_formatDate(_dateRange!.start)} - ${_formatDate(_dateRange!.end)}'
                              : 'Select dates',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            const SizedBox(width: 10),

            // Clear all filters chip
            if (_filterConclusion != null || _filterEmployee != null || _searchController.text.isNotEmpty)
              Material(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: _clearAllFilters,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.clear_rounded, size: 16, color: Colors.red),
                        SizedBox(width: 6),
                        Text(
                          'Clear',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _filterPill({required IconData icon, required Color color, required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          child,
        ],
      ),
    );
  }

  void _clearAllFilters() {
    setState(() {
      _filterConclusion = null;
      _filterEmployee = null;
      _searchController.clear();
      _setDefaultDateRange();
      _applyFilters();
    });
  }

  // ------------------------------------------------------------------
  // Summary Card
  // ------------------------------------------------------------------
  Widget _buildSummaryCard() {
    final totalCustomers = _filteredCustomers.length;
    final totalVisits = _filteredCustomers.fold<int>(
        0, (sum, c) => sum + ((c["visits"] as List?)?.length ?? 0));

    // Conclusion breakdown
    Map<String, int> conclusionCounts = {};
    for (final c in _filteredCustomers) {
      final visits = c["visits"] as List? ?? [];
      for (final v in visits) {
        final conc = v["conclusion"]?.toString() ?? 'Unknown';
        conclusionCounts[conc] = (conclusionCounts[conc] ?? 0) + 1;
      }
    }

    // Build stat items in a horizontally scrollable row
    List<Widget> statChildren = [
      _statItem(Icons.people_alt_rounded, totalCustomers.toString(), 'Customers', color: Colors.blue),
      _statItem(Icons.history_rounded, totalVisits.toString(), 'Visits', color: Colors.teal),
    ];

    // Add top conclusion stats (max 3)
    final sortedConclusions = conclusionCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (var entry in sortedConclusions.take(3)) {
      statChildren.add(
        _statItem(
          Icons.label_rounded,
          '${entry.value}',
          entry.key,
          color: _getConclusionColor(entry.key),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      color: const Color(0xFFF3F5FA),
      child: SizedBox(
        height: 68,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: statChildren.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, index) => statChildren[index],
        ),
      ),
    );
  }

  Widget _statItem(IconData icon, String value, String label, {Color color = AppColors.primary}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.18), color.withOpacity(0.08)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5, height: 1.0),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(fontSize: 10.5, color: Colors.grey[600], fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Customer List Card
  // ------------------------------------------------------------------
  Widget _buildCustomerCard(Map<String, dynamic> customer, List visitsInRange) {
    final name = (customer["name"] ?? '') as String;
    final statusColor = _getStatusColor(customer["status"] ?? '');

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
          onTap: () => _navigateToCustomerDetail(customer),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 12,
                bottom: 12,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
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
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(Icons.phone_rounded, size: 12, color: Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Text(
                                customer["phone"] ?? '',
                                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (visitsInRange.isNotEmpty)
                                _tinyChip(
                                  '${visitsInRange.length} visit${visitsInRange.length > 1 ? 's' : ''}',
                                  AppColors.primary,
                                  icon: Icons.event_repeat_rounded,
                                ),
                              _tinyChip(
                                customer["status"] ?? '',
                                statusColor,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tinyChip(String label, Color color, {IconData? icon}) {
    if (label.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Empty State
  // ------------------------------------------------------------------
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.search_off_rounded, size: 52, color: AppColors.primary.withOpacity(0.6)),
            ),
            const SizedBox(height: 20),
            const Text(
              'No customers found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Try adjusting your filters or search terms',
              style: TextStyle(color: Colors.grey[600], fontSize: 13.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: _clearAllFilters,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reset All Filters'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// CUSTOMER DETAIL SCREEN (UI polished — logic unchanged)
// ------------------------------------------------------------
class CustomerDetailScreen extends StatefulWidget {
  final Map<String, dynamic> customer;
  final List<Map<String, dynamic>> employees;

  const CustomerDetailScreen({
    super.key,
    required this.customer,
    required this.employees,
  });

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  late Map<String, dynamic> customer;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    customer = widget.customer;
  }

  void _navigateToAddVisit() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddCustomerScreen(
          employees: widget.employees,
          customers: [],
          customerToEdit: customer,
          isAddingVisit: true,
        ),
      ),
    ).then((result) {
      if (result == true) _refreshCustomerData();
    });
  }

  Future<void> _refreshCustomerData() async {
    setState(() => isLoading = true);
    try {
      final api = ApiService();
      final response = await api.getCustomerById(customer['_id'].toString());
      if (response['success'] == true) {
        setState(() {
          customer = response['data'];
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint('Error refreshing customer: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visits = customer["visits"] as List? ?? [];
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FA),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(customer["name"] ?? "Customer Details", style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 18),
                  _buildVisitHistory(visits),
                  const SizedBox(height: 16),
                  _buildDetailCard(),
                  const SizedBox(height: 16),
                  _buildAdditionalInfo(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.16),
              border: Border.all(color: Colors.white.withOpacity(0.55), width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text(
              customer["name"]?[0]?.toUpperCase() ?? '?',
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            customer["name"] ?? '',
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  customer["status"] ?? '',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              if (customer["customerClass"] != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '⭐ ${customer["customerClass"]}',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.event_repeat_rounded, size: 14, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  '${(customer["visits"] as List?)?.length ?? 0} total visits',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 17, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildVisitHistory(List visits) {
    if (visits.isEmpty) {
      return _sectionCard(
        title: 'Visit History',
        icon: Icons.history_rounded,
        child: Text('No visit history', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
      );
    }
    return _sectionCard(
      title: 'Visit History',
      icon: Icons.history_rounded,
      child: Column(
        children: visits.reversed.map((visit) {
          final conclusion = visit["conclusion"]?.toString() ?? '';
          final conclusionColor = conclusion.isNotEmpty ? _getConclusionColor(conclusion) : Colors.grey;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: AppColors.primary.withOpacity(0.12),
                  child: Text(
                    (visit["visitNumber"] ?? '').toString(),
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        visit["purposeOfVisit"] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.schedule_rounded, size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            _formatDateTime(visit["visitDate"]),
                            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                      if (conclusion.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: conclusionColor.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            conclusion,
                            style: TextStyle(color: conclusionColor, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                      if ((visit["gold"] != null && visit["gold"].toString().isNotEmpty) ||
                          (visit["diamond"] != null && visit["diamond"].toString().isNotEmpty) ||
                          (visit["polki"] != null && visit["polki"].toString().isNotEmpty)) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (visit["gold"] != null && visit["gold"].toString().isNotEmpty)
                              _miniInfoChip(Icons.star_rounded, 'Gold: ${visit["gold"]}', Colors.amber.shade800),
                            if (visit["diamond"] != null && visit["diamond"].toString().isNotEmpty)
                              _miniInfoChip(Icons.diamond_rounded, 'Diamond: ${visit["diamond"]}', Colors.blue.shade700),
                            if (visit["polki"] != null && visit["polki"].toString().isNotEmpty)
                              _miniInfoChip(Icons.auto_awesome_rounded, 'Polki: ${visit["polki"]}', Colors.purple.shade700),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _miniInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildDetailCard() {
    return _sectionCard(
      title: 'Personal Info',
      icon: Icons.person_rounded,
      child: Column(
        children: [
          _detailRow(Icons.badge_outlined, 'Name', customer["name"] ?? ''),
          _detailRow(Icons.phone_outlined, 'Phone', customer["phone"] ?? ''),
          _detailRow(Icons.email_outlined, 'Email', customer["email"] ?? ''),
          _detailRow(Icons.location_on_outlined, 'Address', customer["address"] ?? '', isLast: true),
        ],
      ),
    );
  }

  Widget _buildAdditionalInfo() {
    return _sectionCard(
      title: 'Additional Info',
      icon: Icons.info_outline_rounded,
      child: Column(
        children: [
          _detailRow(
            Icons.support_agent_outlined,
            'Assigned To',
            customer["assignedTo"] is Map
                ? customer["assignedTo"]["name"]?.toString() ?? ''
                : customer["assignedTo"]?.toString() ?? 'Not assigned',
          ),
          _detailRow(Icons.cake_outlined, 'Birthday', customer["birthday"] ?? ''),
          _detailRow(Icons.favorite_border_rounded, 'Anniversary', customer["anniversary"] ?? ''),
          _detailRow(Icons.work_outline_rounded, 'Profession', customer["profession"] ?? ''),
          _detailRow(Icons.groups_outlined, 'Community', customer["community"] ?? ''),
          _detailRow(Icons.calendar_today_outlined, 'Created', _formatDateTime(customer["createdAt"])),
          _detailRow(Icons.update_rounded, 'Updated', _formatDateTime(customer["updatedAt"]), isLast: true),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value, {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: Colors.grey.shade100, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade500),
          const SizedBox(width: 10),
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Active':
        return Colors.green;
      case 'Inactive':
        return Colors.red;
      case 'Lead':
        return Colors.orange;
      case 'Prospect':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Color _getConclusionColor(String conclusion) {
    switch (conclusion) {
      case 'Sold':
        return Colors.green;
      case 'Shortlisted':
        return Colors.orange;
      case 'Just See':
        return Colors.blue;
      case 'On Order':
        return Colors.purple;
      case 'On Approval':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(dynamic dateString) {
    try {
      if (dateString == null) return 'N/A';
      final date = DateTime.parse(dateString.toString());
      return DateFormat('dd-MM-yyyy HH:mm').format(date);
    } catch (_) {
      return dateString.toString();
    }
  }
}