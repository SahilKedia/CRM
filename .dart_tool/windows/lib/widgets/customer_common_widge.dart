// Shared widgets & helpers used by both AddCustomerScreen and EditCustomerScreen.
//
// Pulling these out of the old monolithic screen means the two screens stay
// small and focused, and any visual tweak (card style, image viewer, dropdown
// look) only needs to happen in one place.
//
// Drop this in lib/widgets/customer_common_widgets.dart (adjust the relative
// imports below if your project layout differs).

import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

// ============================================================================
// FORMAT / MAPPING HELPERS
// ============================================================================

String formatDate(DateTime date) {
  final year = date.year.toString();
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String formatTimeOfDay(TimeOfDay t) {
  final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
  final m = t.minute.toString().padLeft(2, '0');
  final period = t.period == DayPeriod.am ? 'AM' : 'PM';
  return '$h:$m $period';
}

String formatVisitDate(dynamic rawDate) {
  if (rawDate == null) return 'an unknown date';
  DateTime? date;
  if (rawDate is DateTime) {
    date = rawDate;
  } else {
    date = DateTime.tryParse(rawDate.toString());
  }
  if (date == null) return rawDate.toString();
  const monthsShort = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  final local = date.toLocal();
  return '${local.day} ${monthsShort[local.month - 1]} ${local.year}';
}

List<String> parseImageUrls(dynamic imageData) {
  if (imageData == null) return [];
  if (imageData is List) {
    return imageData
        .where((item) => item != null)
        .map((item) => item.toString())
        .where((url) => url.isNotEmpty)
        .toList();
  }
  if (imageData is String && imageData.isNotEmpty) {
    return [imageData];
  }
  return [];
}

String mapConclusionToServer(String uiValue) {
  switch (uiValue) {
    case 'Pending': return 'pending';
    case 'Sold': return 'sold';
    case 'Shortlisted': return 'shortlisted';
    case 'Just See': return 'just see';
    case 'On Order': return 'on order';
    case 'On Approval': return 'on approval';
    default: return uiValue.toLowerCase();
  }
}

String mapConclusionToUI(String serverValue) {
  switch (serverValue) {
    case 'pending': return 'Pending';
    case 'sold': return 'Sold';
    case 'shortlisted': return 'Shortlisted';
    case 'just see': return 'Just See';
    case 'on order': return 'On Order';
    case 'on approval': return 'On Approval';
    default: return serverValue;
  }
}

const List<String> kMonths = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];

const List<String> kTitleOptions = ['Mr.', 'Mrs.', 'Ms.', 'Dr.'];

const List<String> kDefaultProfessionOptions = [
  'Doctor', 'Business Man', 'Teacher', 'Police', 'Others'
];
const List<String> kDefaultCommunityOptions = [
  'HNI/IMP', 'Very Good', 'Good', 'Medium', 'Small'
];

const List<Map<String, String>> kConclusionOptions = [
  {'value': 'Pending', 'label': 'Pending'},
  {'value': 'Sold', 'label': 'Sold'},
  {'value': 'Shortlisted', 'label': 'Shortlisted'},
  {'value': 'Just See', 'label': 'Just See'},
  {'value': 'On Order', 'label': 'On Order'},
  {'value': 'On Approval', 'label': 'On Approval'},
];

// ============================================================================
// SECTION CARD — consistent white card with icon + title header
// ============================================================================

class SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;

  const SectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ============================================================================
// STICKY BOTTOM SAVE BAR
// ============================================================================

class StickySaveBar extends StatelessWidget {
  final bool isLoading;
  final String label;
  final VoidCallback? onSave;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const StickySaveBar({
    super.key,
    required this.isLoading,
    required this.label,
    required this.onSave,
    this.secondaryLabel,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, -3)),
        ],
      ),
      child: Row(
        children: [
          if (secondaryLabel != null) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: isLoading ? null : onSecondary,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(secondaryLabel!, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: isLoading ? null : onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                    )
                  : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// GENERIC DROPDOWN FIELD
// ============================================================================

class AppDropdownField<T> extends StatelessWidget {
  final String label;
  final IconData icon;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? hint;
  final bool loading;
  final bool dense;
  final String? Function(T?)? validator;

  const AppDropdownField({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
    this.loading = false,
    this.dense = false,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        DropdownButtonHideUnderline(
          child: DropdownButtonFormField<T>(
            value: value,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.textSecondary),
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: loading ? const Color(0xFFF1F1F3) : Colors.white,
              hintText: loading ? 'Loading...' : hint,
              hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
              prefixIcon: dense ? null : Icon(icon, size: 20, color: AppColors.textSecondary),
              contentPadding: EdgeInsets.symmetric(horizontal: dense ? 10 : 12, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.red),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.red, width: 1.4),
              ),
            ),
            selectedItemBuilder: dense
                ? (context) => items
                    .map((item) => Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            (item.value as Object?)?.toString() ?? '',
                            overflow: TextOverflow.visible,
                            softWrap: false,
                            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                          ),
                        ))
                    .toList()
                : null,
            items: loading ? const [] : items,
            onChanged: loading ? null : onChanged,
            validator: validator,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// CONCLUSION SELECTOR — chip-based, friendlier than a plain dropdown
// ============================================================================

class ConclusionSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const ConclusionSelector({super.key, required this.value, required this.onChanged});

  Color _colorFor(String v) {
    switch (v) {
      case 'Sold': return AppColors.success;
      case 'On Order': return Colors.blue;
      case 'On Approval': return Colors.purple;
      case 'Shortlisted': return Colors.teal;
      case 'Just See': return Colors.orange;
      default: return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Conclusion', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kConclusionOptions.map((opt) {
            final selected = value == opt['value'];
            final color = _colorFor(opt['value']!);
            return ChoiceChip(
              label: Text(opt['label']!),
              selected: selected,
              onSelected: (_) => onChanged(opt['value']!),
              selectedColor: color.withOpacity(0.15),
              backgroundColor: const Color(0xFFF4F5F7),
              side: BorderSide(color: selected ? color : AppColors.border),
              labelStyle: TextStyle(
                color: selected ? color : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ============================================================================
// IMAGE UPLOAD SECTION (gold / diamond / polki style multi-image picker)
// ============================================================================

class ImageUploadSection extends StatelessWidget {
  final String label;
  final List<File> localImages;
  final List<String> existingUrls;
  final VoidCallback onAddPhoto;
  final void Function(int index) onRemoveLocal;
  final void Function({List<String>? networkUrls, List<File>? files, required int initialIndex, String? title}) onViewImage;

  const ImageUploadSection({
    super.key,
    required this.label,
    required this.localImages,
    required this.existingUrls,
    required this.onAddPhoto,
    required this.onRemoveLocal,
    required this.onViewImage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        if (existingUrls.isNotEmpty) ...[
          const Text('Previously uploaded:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: existingUrls.length,
              itemBuilder: (context, index) {
                final url = ApiService.getImageUrl(existingUrls[index]);
                return GestureDetector(
                  onTap: () => onViewImage(
                    networkUrls: existingUrls.map((u) => ApiService.getImageUrl(u)).toList(),
                    initialIndex: index,
                    title: label,
                  ),
                  child: Container(
                    width: 90,
                    height: 90,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        url,
                        fit: BoxFit.cover,
                        width: 90,
                        height: 90,
                        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 36),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (localImages.isNotEmpty)
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: localImages.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    GestureDetector(
                      onTap: () => onViewImage(files: localImages, initialIndex: index, title: label),
                      child: Container(
                        width: 100,
                        height: 100,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(localImages[index], fit: BoxFit.cover, width: 100, height: 100),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 10,
                      child: GestureDetector(
                        onTap: () => onRemoveLocal(index),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onAddPhoto,
          borderRadius: BorderRadius.circular(12),
          child: DottedBox(
            child: Column(
              children: [
                Icon(Icons.add_a_photo_outlined, size: 26, color: AppColors.primary.withOpacity(0.7)),
                const SizedBox(height: 4),
                Text(
                  localImages.isNotEmpty ? '${localImages.length} image(s) added — tap to add more' : 'Add $label',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Simple dashed-look upload box (plain border kept subtle & rounded — avoids
/// pulling in a dashed-border package while still reading as an "upload slot").
class DottedBox extends StatelessWidget {
  final Widget child;
  const DottedBox({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.04),
        border: Border.all(color: AppColors.primary.withOpacity(0.25), width: 1.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

// ============================================================================
// PROFILE PHOTO PICKER (circular avatar with camera badge)
// ============================================================================

class ProfileImagePicker extends StatelessWidget {
  final File? localFile;
  final String? existingUrl;
  final VoidCallback onPick;
  final void Function({List<String>? networkUrls, List<File>? files, required int initialIndex, String? title}) onView;
  final String title;

  const ProfileImagePicker({
    super.key,
    required this.localFile,
    required this.existingUrl,
    required this.onPick,
    required this.onView,
    this.title = 'Photo',
  });

  @override
  Widget build(BuildContext context) {
    ImageProvider? imageProvider;
    if (localFile != null) {
      imageProvider = FileImage(localFile!);
    } else if (existingUrl != null && existingUrl!.isNotEmpty) {
      imageProvider = NetworkImage(ApiService.getImageUrl(existingUrl!));
    }

    return GestureDetector(
      onTap: imageProvider != null
          ? () {
              if (localFile != null) {
                onView(files: [localFile!], initialIndex: 0, title: title);
              } else if (existingUrl != null) {
                onView(networkUrls: [ApiService.getImageUrl(existingUrl!)], initialIndex: 0, title: title);
              }
            }
          : onPick,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primary.withOpacity(0.4)],
              ),
            ),
            child: CircleAvatar(
              radius: 48,
              backgroundColor: Colors.white,
              child: CircleAvatar(
                radius: 45,
                backgroundColor: AppColors.border,
                backgroundImage: imageProvider,
                child: imageProvider == null
                    ? const Icon(Icons.person, size: 46, color: AppColors.textSecondary)
                    : null,
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: onPick,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// FULL SCREEN IMAGE VIEWER (public, shared)
// ============================================================================

class FullScreenImageViewer extends StatefulWidget {
  final List<String>? networkUrls;
  final List<File>? files;
  final int initialIndex;
  final String? title;

  const FullScreenImageViewer({
    super.key,
    this.networkUrls,
    this.files,
    required this.initialIndex,
    this.title,
  });

  static void open(
    BuildContext context, {
    List<String>? networkUrls,
    List<File>? files,
    required int initialIndex,
    String? title,
  }) {
    final itemCount = networkUrls?.length ?? files?.length ?? 0;
    if (itemCount == 0) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (context, animation, secondaryAnimation) => FullScreenImageViewer(
          networkUrls: networkUrls,
          files: files,
          initialIndex: initialIndex,
          title: title,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  late final PageController _pageController;
  late int _currentIndex;

  int get _itemCount => widget.networkUrls?.length ?? widget.files?.length ?? 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          _itemCount > 1 ? '${widget.title ?? 'Photo'} (${_currentIndex + 1}/$_itemCount)' : (widget.title ?? 'Photo'),
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
      ),
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: PageView.builder(
          controller: _pageController,
          itemCount: _itemCount,
          onPageChanged: (i) => setState(() => _currentIndex = i),
          itemBuilder: (context, index) {
            final child = widget.networkUrls != null
                ? Image.network(
                    widget.networkUrls![index],
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
                    ),
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(child: CircularProgressIndicator(color: Colors.white70));
                    },
                  )
                : Image.file(widget.files![index], fit: BoxFit.contain);

            return GestureDetector(
              onTap: () {},
              child: InteractiveViewer(minScale: 1, maxScale: 4, child: Center(child: child)),
            );
          },
        ),
      ),
    );
  }
}

// ============================================================================
// DUPLICATE WARNING BANNER
// ============================================================================

class DuplicateWarningBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onTap;

  const DuplicateWarningBanner({super.key, required this.message, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withOpacity(0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), shape: BoxShape.circle),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.deepOrange, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.deepOrange, fontSize: 13, height: 1.3)),
            ),
            if (onTap != null) const Icon(Icons.chevron_right, color: Colors.deepOrange, size: 18),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// LOADING OVERLAY BODY
// ============================================================================

class LoadingBody extends StatelessWidget {
  final String message;
  const LoadingBody({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}