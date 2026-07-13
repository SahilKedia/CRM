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
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
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
            const SizedBox(height: 12),
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
                minimumSize: const Size(double.infinity, 48),
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
  int _conclusionColumnIndex(String conclusion) {
    final c = _normalizeConclusion(conclusion);
    if (c.contains('sold')) return 9;
    if (c.contains('shortlist')) return 10;
    if (c.contains('just see') || c.contains('justsee')) return 11;
    if (c.contains('order')) return 12;
    if (c.contains('requirement') || c.contains('pending')) return 13;
    if (c.contains('approval')) return 14;
    return -1;
  }

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

  /// Downloads and embeds the first image in [imageUrls] at the given cell.
  /// Returns true on success so the caller can report how many images
  /// actually made it into the sheet vs silently failed.
  Future<bool> _embedVisitImage({
    required Sheet sheet,
    required int columnIndex,
    required int rowIndex,
    required List? imageUrls,
    int size = 85,
  }) async {
    if (imageUrls == null || imageUrls.isEmpty) return false;
    final raw = imageUrls.first?.toString() ?? '';
    if (raw.isEmpty) return false;

    final url = _resolveImageUrl(raw);
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      debugPrint('Skipping image — not a valid absolute URL: "$raw" '
          '(resolved: "$url").');
      return false;
    }

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        sheet.insertImage(
          response.bodyBytes,
          anchor: CellIndex.indexByColumnRow(columnIndex: columnIndex, rowIndex: rowIndex),
          width: size,
          height: size,
        );
        return true;
      }
      debugPrint('Image fetch failed for $url — HTTP ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('Failed to embed image from $url: $e');
      return false;
    }
  }

  // --------------------- CORRECTED COLUMN LAYOUT (Reminder removed) ---------------------
  static const int _colDate = 0;
  static const int _colSerial = 1;
  static const int _colName = 2;
  static const int _colPhone = 3;
  static const int _colAddress = 4;
  static const int _colPurpose = 5;
  static const int _colGold = 6;
  static const int _colDiamond = 7;
  static const int _colPolki = 8;
  // 9..14 are the status columns (SOLD/SHORTLIST/JUST SEE/ON ORDER/REQUIREMENT/APPROVAL)
  static const int _colWhoAttend = 15;
  static const int _colHelper = 16;
  static const int _colMedia = 17;        // previously 18
  static const int _colConclusion = 18;   // previously 19
  static const int _totalColumns = 19;    // indices 0..18

  /// Builds the workbook in the same layout as your printed register:
  /// rows grouped under a date header, Gold/Diamond/Polki as image-only
  /// columns, the item description routed into the matching status column,
  /// the whole row colour-coded by conclusion, and a totals footer.
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
      // Change BorderStyle to Thin / Medium / Thick / Double to taste.
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

      final headers = <String>[
        'DATE', 'S.NO', 'CUSTOMER NAME', 'PHONE NO', 'ADDRESS',
        'PURPOSE OF VISIT', 'GOLD', 'DIAMOND', 'POLKI',
        'SOLD', 'SHORTLIST', 'JUST SEE', 'ON ORDER', 'REQUIREMENT', 'APPROVAL',
        'WHO ATTEND', 'HELPER', 'MEDIA', 'CONCLUSION',
      ];

      for (int i = 0; i < headers.length; i++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
        );
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = headerStyle;
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
        _colGold: 26,
        _colDiamond: 26,
        _colPolki: 26,
        9: 13,   // SOLD
        10: 13,  // SHORTLIST
        11: 13,  // JUST SEE
        12: 13,  // ON ORDER
        13: 14,  // REQUIREMENT
        14: 13,  // APPROVAL
        _colWhoAttend: 15,
        _colHelper: 12,
        // Reminder column removed
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

          // Colour only the Gold → Conclusion band, matching your printed
          // report — DATE/S.NO/NAME/PHONE/ADDRESS/PURPOSE stay white.
          // Every cell (coloured or not) gets the same visible border.
          final coloredStyle = CellStyle(
            verticalAlign: VerticalAlign.Center,
            textWrapping: TextWrapping.WrapText,
            backgroundColorHex: rowColor,
            leftBorder: cellBorder,
            rightBorder: cellBorder,
            topBorder: cellBorder,
            bottomBorder: cellBorder,
          );
          final plainStyle = CellStyle(
            verticalAlign: VerticalAlign.Center,
            textWrapping: TextWrapping.WrapText,
            leftBorder: cellBorder,
            rightBorder: cellBorder,
            topBorder: cellBorder,
            bottomBorder: cellBorder,
          );
          CellStyle styleForColumn(int col) =>
              col >= _colGold ? coloredStyle : plainStyle;

          for (int col = 0; col < _totalColumns; col++) {
            sheet
                .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex))
                .cellStyle = styleForColumn(col);
          }

          void setCell(int col, String value) {
            final cell = sheet.cell(
              CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex),
            );
            cell.value = TextCellValue(value);
            // Reapply style after setting value — some excel_plus versions
            // reset the cell's style when .value is assigned afterwards,
            // which was causing the text-overflow you saw.
            cell.cellStyle = styleForColumn(col);
          }

          setCell(_colSerial, serial.toString());
          setCell(_colName, customer['name']?.toString() ?? '');
          setCell(_colPhone, customer['phone']?.toString() ?? '');
          setCell(_colAddress, customer['address']?.toString() ?? '');
          setCell(_colPurpose, visit['purposeOfVisit']?.toString() ?? '');
          // Gold/Diamond/Polki columns are image-only, no text.
          if (statusCol != -1) {
            setCell(statusCol, visit['purposeOfVisit']?.toString() ?? '');
          }
          setCell(_colWhoAttend, _resolveEmployeeName(visit['whoAttend']));
          setCell(_colHelper, visit['helper']?.toString() ?? '');
          // Reminder column removed – no call to setCell for it.
          // _colMedia intentionally left blank — no `media` field in your data yet.
          setCell(_colConclusion, _titleCase(conclusionRaw));

          // ---- Dynamic row height so wrapped text and larger images fit ----
          final address = customer['address']?.toString() ?? '';
          final purpose = visit['purposeOfVisit']?.toString() ?? '';
          final longest = address.length > purpose.length ? address : purpose;
          final estimatedLines = (longest.length / 32).ceil().clamp(1, 8);
          final textHeight = (estimatedLines * 15).toDouble();
          // Images are 85px (~64pt) tall — make sure the row is tall enough.
          final rowHeight = textHeight < 70 ? 70.0 : textHeight;
          sheet.setRowHeight(rowIndex, rowHeight.clamp(20, 160));

          // ---- Embed Gold / Diamond / Polki images (first image each) ----
          imagesAttempted += (visit['goldImages'] as List? ?? []).isNotEmpty ? 1 : 0;
          imagesAttempted += (visit['diamondImages'] as List? ?? []).isNotEmpty ? 1 : 0;
          imagesAttempted += (visit['polkiImages'] as List? ?? []).isNotEmpty ? 1 : 0;

          if (await _embedVisitImage(
            sheet: sheet,
            columnIndex: _colGold,
            rowIndex: rowIndex,
            imageUrls: visit['goldImages'] as List?,
          )) {
            imagesEmbedded++;
          }
          if (await _embedVisitImage(
            sheet: sheet,
            columnIndex: _colDiamond,
            rowIndex: rowIndex,
            imageUrls: visit['diamondImages'] as List?,
          )) {
            imagesEmbedded++;
          }
          if (await _embedVisitImage(
            sheet: sheet,
            columnIndex: _colPolki,
            rowIndex: rowIndex,
            imageUrls: visit['polkiImages'] as List?,
          )) {
            imagesEmbedded++;
          }

          rowIndex++;
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
      SnackBar(content: Text(msg), backgroundColor: color),
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
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search by name, phone, email...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                style: const TextStyle(color: Colors.black),
                onChanged: (_) => _applyFilters(),
              )
            : const Text('Customer Reports'),
        backgroundColor: AppColors.primary,
        actions: [
          if (!_isSearching)
            IconButton(
              icon: _isExporting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.file_download),
              onPressed: _isExporting ? null : _exportToExcel,
              tooltip: 'Export to Excel',
            ),
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => setState(() => _isSearching = true),
            ),
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                _searchController.clear();
                _isSearching = false;
                _applyFilters();
                FocusScope.of(context).unfocus();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // ---- FILTER BAR ----
          _buildFilterBar(),

          // ---- SUMMARY CARD ----
          _buildSummaryCard(),

          // ---- EXPORT PROGRESS ----
          if (_isExporting && _exportStatus.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: AppColors.primary.withOpacity(0.08),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(_exportStatus, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),

          // ---- CUSTOMER LIST ----
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCustomers.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
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

                          return GestureDetector(
                            onTap: () => _navigateToCustomerDetail(customer),
                            child: Card(
                              elevation: 3,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.primary.withOpacity(0.15),
                                  child: Text(
                                    customer["name"]?[0]?.toUpperCase() ?? '?',
                                    style: const TextStyle(color: AppColors.primary),
                                  ),
                                ),
                                title: Text(
                                  customer["name"] ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(customer["phone"] ?? ''),
                                    if (visitsInRange.isNotEmpty)
                                      Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${visitsInRange.length} visit${visitsInRange.length > 1 ? 's' : ''} in period',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(customer["status"] ?? '')
                                            .withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        customer["status"] ?? '',
                                        style: TextStyle(
                                          color: _getStatusColor(customer["status"] ?? ''),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios),
                              ),
                            ),
                          );
                        },
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Date range dropdown
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: DropdownButton<ReportType>(
                value: _reportType,
                underline: const SizedBox(),
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
            const SizedBox(width: 12),

            // Conclusion filter
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: DropdownButton<String>(
                value: _filterConclusion,
                hint: const Text('Conclusion'),
                underline: const SizedBox(),
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
            const SizedBox(width: 12),

            // Employee filter
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: DropdownButton<String>(
                value: _filterEmployee,
                hint: const Text('Employee'),
                underline: const SizedBox(),
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
            const SizedBox(width: 12),

            // Custom date picker (visible only when custom is selected)
            if (_reportType == ReportType.custom)
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: TextButton.icon(
                  onPressed: _pickCustomDateRange,
                  icon: const Icon(Icons.edit_calendar, size: 18),
                  label: Text(
                    _dateRange != null
                        ? '${_formatDate(_dateRange!.start)} - ${_formatDate(_dateRange!.end)}'
                        : 'Select dates',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),

            const SizedBox(width: 12),

            // Clear all filters chip
            if (_filterConclusion != null || _filterEmployee != null || _searchController.text.isNotEmpty)
              ActionChip(
                label: const Text('Clear Filters'),
                onPressed: _clearAllFilters,
                backgroundColor: Colors.grey[200],
                avatar: const Icon(Icons.clear, size: 16),
              ),
          ],
        ),
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

    // Build stat items in a Wrap for better responsiveness
    List<Widget> statChildren = [
      _statItem(Icons.people, totalCustomers.toString(), 'Customers', color: Colors.blue),
      _statItem(Icons.history, totalVisits.toString(), 'Visits', color: Colors.teal),
    ];

    // Add top conclusion stats (max 3)
    final sortedConclusions = conclusionCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (var entry in sortedConclusions.take(3)) {
      statChildren.add(
        _statItem(
          Icons.label,
          '${entry.value}',
          entry.key,
          color: _getConclusionColor(entry.key),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      color: Colors.grey[50],
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        alignment: WrapAlignment.spaceAround,
        children: statChildren,
      ),
    );
  }

  Widget _statItem(IconData icon, String value, String label, {Color color = AppColors.primary}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
            ],
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No customers found',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters or search terms',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _clearAllFilters,
            icon: const Icon(Icons.refresh),
            label: const Text('Reset All Filters'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// CUSTOMER DETAIL SCREEN (unchanged)
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
      appBar: AppBar(
        title: Text(customer["name"] ?? "Customer Details"),
        backgroundColor: AppColors.primary,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _navigateToAddVisit,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Add New Visit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                  const SizedBox(height: 16),
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
    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: AppColors.primary.withOpacity(0.15),
            child: Text(
              customer["name"]?[0]?.toUpperCase() ?? '?',
              style: const TextStyle(fontSize: 40, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 8),
          Text(customer["name"] ?? '', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(customer["status"] ?? '').withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(customer["status"] ?? '',
                    style: TextStyle(color: _getStatusColor(customer["status"] ?? ''))),
              ),
              const SizedBox(width: 8),
              if (customer["customerClass"] != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('⭐ ${customer["customerClass"]}',
                      style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text('${(customer["visits"] as List?)?.length ?? 0} total visits',
              style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildVisitHistory(List visits) {
    if (visits.isEmpty) {
      return Card(
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text('No visit history', style: TextStyle(color: Colors.grey)),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Visit History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...visits.reversed.map((visit) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text((visit["visitNumber"] ?? '').toString()),
                ),
                title: Text('Purpose: ${visit["purposeOfVisit"] ?? ''}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Date: ${_formatDateTime(visit["visitDate"])}'),
                    if (visit["conclusion"] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getConclusionColor(visit["conclusion"]).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(visit["conclusion"] ?? '',
                            style: TextStyle(color: _getConclusionColor(visit["conclusion"]))),
                      ),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (visit["gold"] != null && visit["gold"].toString().isNotEmpty)
                          Chip(label: Text('Gold: ${visit["gold"]}'), avatar: const Icon(Icons.star)),
                        if (visit["diamond"] != null && visit["diamond"].toString().isNotEmpty)
                          Chip(label: Text('Diamond: ${visit["diamond"]}'), avatar: const Icon(Icons.diamond)),
                        if (visit["polki"] != null && visit["polki"].toString().isNotEmpty)
                          Chip(label: Text('Polki: ${visit["polki"]}'), avatar: const Icon(Icons.auto_awesome)),
                      ],
                    ),
                  ],
                ),
                isThreeLine: true,
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Personal Info', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            _detailRow('Name', customer["name"] ?? ''),
            _detailRow('Phone', customer["phone"] ?? ''),
            _detailRow('Email', customer["email"] ?? ''),
            _detailRow('Address', customer["address"] ?? ''),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Additional Info', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            _detailRow('Assigned To', customer["assignedTo"] is Map
                ? customer["assignedTo"]["name"]?.toString() ?? ''
                : customer["assignedTo"]?.toString() ?? 'Not assigned'),
            _detailRow('Birthday', customer["birthday"] ?? ''),
            _detailRow('Anniversary', customer["anniversary"] ?? ''),
            _detailRow('Profession', customer["profession"] ?? ''),
            _detailRow('Community', customer["community"] ?? ''),
            _detailRow('Created', _formatDateTime(customer["createdAt"])),
            _detailRow('Updated', _formatDateTime(customer["updatedAt"])),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value)),
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