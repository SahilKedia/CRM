// import 'package:flutter/material.dart';
// import '../services/api_service.dart';
// import '../theme/app_theme.dart';

// class RemindersScreen extends StatefulWidget {
//   final List<Map<String, dynamic>> customers;
//   final Map<String, dynamic> user;

//   const RemindersScreen({
//     Key? key,
//     required this.customers,
//     required this.user,
//   }) : super(key: key);

//   @override
//   State<RemindersScreen> createState() => _RemindersScreenState();
// }

// class _RemindersScreenState extends State<RemindersScreen> {
//   // ---- Reuse the same date parser from CustomerListScreen ----
//   (int month, int day)? _parseDate(String dateStr) {
//     dateStr = dateStr.trim();
//     if (dateStr.isEmpty) return null;
//     if (dateStr.contains("T")) {
//       dateStr = dateStr.split("T").first;
//     }
//     final parts = dateStr.split("-");
//     try {
//       if (parts.length == 2) {
//         final day = int.parse(parts[0]);
//         final month = int.parse(parts[1]);
//         return (month, day);
//       }
//       if (parts.length == 3) {
//         final month = int.parse(parts[1]);
//         final day = int.parse(parts[2]);
//         return (month, day);
//       }
//     } catch (_) {}
//     return null;
//   }

//   // Parse ISO datetime string to DateTime
//   DateTime? _parseDateTime(String dateTimeStr) {
//     try {
//       return DateTime.parse(dateTimeStr);
//     } catch (_) {
//       return null;
//     }
//   }

//   // ---- Build the list of upcoming events (including reminders) ----
//   List<Map<String, dynamic>> _buildUpcomingEvents() {
//     final List<Map<String, dynamic>> events = [];
//     final now = DateTime.now();
//     final today = DateTime(now.year, now.month, now.day);

//     for (var customer in widget.customers) {
//       final name = (customer['name'] ?? '').toString();

//       // Helper to add birthday/anniversary events
//       void addEvent(String? dateString, bool isBirthday) {
//         if (dateString == null || dateString.isEmpty) return;
//         final parsed = _parseDate(dateString);
//         if (parsed == null) return;

//         final (month, day) = parsed;
//         DateTime eventDate = DateTime(now.year, month, day);
//         if (eventDate.compareTo(today) < 0) {
//           eventDate = DateTime(now.year + 1, month, day);
//         }

//         final diff = eventDate.difference(today).inDays;
//         if (diff >= 0 && diff <= 7) {
//           events.add({
//             'customerName': name,
//             'customerId': customer['_id'],
//             'date': eventDate,
//             'daysRemaining': diff,
//             'isBirthday': isBirthday,
//             'isReminder': false,
//             'customer': customer,
//           });
//         }
//       }

//       // --- Add birthday and anniversary ---
//       addEvent(customer['birthday'], true);
//       addEvent(customer['anniversary'], false);

//       // --- Add reminders from customer ---
//       final reminderData = customer['reminder'];
//       if (reminderData != null) {
//         // If it's a list, iterate; if it's a single map, treat as list of one
//         List reminders = [];
//         if (reminderData is List) {
//           reminders = reminderData;
//         } else if (reminderData is Map) {
//           reminders = [reminderData];
//         }

//         for (var reminder in reminders) {
//           // 🔥 FIX: Show ALL pending reminders, even if they've passed
//           // (but we'll show them as "Overdue" instead of filtering them out)
//           if (reminder['status'] != 'pending') continue;

//           final dateStr = reminder['date'];
//           if (dateStr == null || dateStr.isEmpty) continue;

//           // Parse the reminder date (ISO format with time)
//           DateTime? reminderDateTime = _parseDateTime(dateStr);
//           if (reminderDateTime == null) continue;

//           // Convert to local time for comparison
//           final localReminderTime = reminderDateTime.toLocal();
//           final daysDiff = localReminderTime.difference(now).inDays;

//           // 🔥 NEW: Show reminders that are overdue (up to 7 days past)
//           // as well as upcoming reminders (up to 7 days future)
//           if (daysDiff >= -7 && daysDiff <= 7) {
//             // Calculate days remaining (negative for overdue)
//             final eventDate = DateTime(
//               localReminderTime.year,
//               localReminderTime.month,
//               localReminderTime.day,
//             );
//             final diff = eventDate.difference(today).inDays;

//             events.add({
//               'customerName': name,
//               'customerId': customer['_id'],
//               'date': eventDate,
//               'time': localReminderTime,
//               'daysRemaining': diff,
//               'isBirthday': false,
//               'isReminder': true,
//               'note': reminder['note'] ?? '',
//               'customer': customer,
//               'reminderData': reminder,
//               'isOverdue': diff < 0,
//               'reminderDateTime': localReminderTime,
//             });
//           }
//         }
//       }
//     }

//     // Sort by days remaining (soonest first, with overdue at the top)
//     events.sort((a, b) {
//       // Show overdue reminders first (negative days)
//       final aOverdue = a['isOverdue'] ?? false;
//       final bOverdue = b['isOverdue'] ?? false;
      
//       if (aOverdue && !bOverdue) return -1;
//       if (!aOverdue && bOverdue) return 1;
      
//       // Then sort by days remaining
//       return a['daysRemaining'].compareTo(b['daysRemaining']);
//     });
    
//     return events;
//   }

//   // Helper for day label with overdue handling
//   String _daysLabel(int days, {bool isOverdue = false}) {
//     if (isOverdue) {
//       final overdueDays = days.abs();
//       if (overdueDays == 0) return 'Overdue - Today';
//       if (overdueDays == 1) return 'Overdue - Yesterday';
//       return 'Overdue - $overdueDays days ago';
//     }
//     if (days == 0) return 'Today';
//     if (days == 1) return 'Tomorrow';
//     return 'In $days days';
//   }

//   // ---- Show reminder details dialog ----
//   void _showReminderDetails(Map<String, dynamic> event) {
//     final isOverdue = event['isOverdue'] ?? false;
//     final days = event['daysRemaining'];
//     final name = event['customerName'];
//     final note = event['note'] ?? 'No note provided';
//     final reminderDateTime = event['reminderDateTime'] as DateTime?;
//     final customer = event['customer'] as Map<String, dynamic>;
    
//     // Format the date and time
//     String formattedDateTime = 'Not set';
//     if (reminderDateTime != null) {
//       formattedDateTime = 
//           '${reminderDateTime.year}-${reminderDateTime.month.toString().padLeft(2, '0')}-${reminderDateTime.day.toString().padLeft(2, '0')} '
//           '${reminderDateTime.hour.toString().padLeft(2, '0')}:${reminderDateTime.minute.toString().padLeft(2, '0')}';
//     }

//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Row(
//           children: [
//             Icon(
//               isOverdue ? Icons.warning_amber_rounded : Icons.notifications_active,
//               color: isOverdue ? Colors.red : AppColors.primary,
//             ),
//             const SizedBox(width: 8),
//             Text(isOverdue ? 'Overdue Reminder' : 'Reminder Details'),
//           ],
//         ),
//         content: SingleChildScrollView(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               // Customer name
//               _buildDetailRow('Customer', name),
//               const SizedBox(height: 8),
              
//               // Date & Time
//               _buildDetailRow('Date & Time', formattedDateTime),
//               const SizedBox(height: 8),
              
//               // Status
//               _buildDetailRow(
//                 'Status', 
//                 isOverdue ? '⚠️ Overdue' : '✅ Upcoming',
//               ),
//               const SizedBox(height: 8),
              
//               // Days
//               _buildDetailRow(
//                 'Days', 
//                 _daysLabel(days, isOverdue: isOverdue),
//               ),
//               const SizedBox(height: 8),
              
//               // Note
//               const Divider(),
//               const Text(
//                 'Note:',
//                 style: TextStyle(
//                   fontWeight: FontWeight.w600,
//                   fontSize: 14,
//                 ),
//               ),
//               const SizedBox(height: 4),
//               Text(
//                 note,
//                 style: const TextStyle(fontSize: 14),
//               ),
              
//               // Phone number if available
//               if (customer['phone'] != null) ...[
//                 const SizedBox(height: 8),
//                 const Divider(),
//                 _buildDetailRow(
//                   'Phone', 
//                   customer['phone'].toString(),
//                 ),
//               ],
//             ],
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Close'),
//           ),
//           if (isOverdue)
//             TextButton(
//               onPressed: () {
//                 Navigator.pop(context);
//                 // Optionally mark as completed or snooze
//                 _showMarkCompletedDialog(event);
//               },
//               child: const Text(
//                 'Mark as Completed',
//                 style: TextStyle(color: Colors.green),
//               ),
//             ),
//         ],
//       ),
//     );
//   }

//   // ---- Mark reminder as completed ----
//   void _showMarkCompletedDialog(Map<String, dynamic> event) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Mark as Completed?'),
//         content: const Text(
//           'Are you sure you want to mark this reminder as completed? '
//           'It will be removed from the reminders list.',
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Cancel'),
//           ),
//           TextButton(
//             onPressed: () async {
//               Navigator.pop(context); // Close the dialog
//               Navigator.pop(context); // Close the details dialog
              
//               final customerId = event['customerId']?.toString();
//               if (customerId != null) {
//                 // Show loading
//                 setState(() {}); // This will trigger a rebuild
                
//                 try {
//                   final result = await ApiService().markReminderCompleted(customerId);
//                   if (result['success'] == true) {
//                     // Refresh the screen by rebuilding
//                     setState(() {});
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       const SnackBar(
//                         content: Text('Reminder marked as completed!'),
//                         backgroundColor: Colors.green,
//                       ),
//                     );
//                   } else {
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       SnackBar(
//                         content: Text('Error: ${result['message'] ?? 'Failed to update'}'),
//                         backgroundColor: Colors.red,
//                       ),
//                     );
//                   }
//                 } catch (e) {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(
//                       content: Text('Error: $e'),
//                       backgroundColor: Colors.red,
//                     ),
//                   );
//                 }
//               }
//             },
//             child: const Text(
//               'Yes, Complete',
//               style: TextStyle(color: Colors.green),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildDetailRow(String label, String value) {
//     return Row(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         SizedBox(
//           width: 80,
//           child: Text(
//             label,
//             style: const TextStyle(
//               fontWeight: FontWeight.w500,
//               color: AppColors.textSecondary,
//               fontSize: 13,
//             ),
//           ),
//         ),
//         Expanded(
//           child: Text(
//             value,
//             style: const TextStyle(
//               fontSize: 13,
//               color: AppColors.textPrimary,
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   // ---- Build a single event tile ----
//   Widget _buildEventTile(Map<String, dynamic> event, BuildContext context) {
//     final isBirthday = event['isBirthday'] ?? false;
//     final isReminder = event['isReminder'] ?? false;
//     final isOverdue = event['isOverdue'] ?? false;
//     final days = event['daysRemaining'];
//     final name = event['customerName'];
//     final customer = event['customer'] as Map<String, dynamic>;
//     final note = event['note'] ?? '';

//     // Colour & icon
//     Color bgColor;
//     Color textColor;
//     IconData icon;
//     String eventType;
//     String subtitleText;

//     if (isReminder) {
//       if (isOverdue) {
//         icon = Icons.warning_amber_rounded;
//         eventType = 'OVERDUE Reminder';
//         subtitleText = '⚠️ ${_daysLabel(days, isOverdue: true)}';
//         bgColor = Colors.red.shade100;
//         textColor = Colors.red.shade900;
//       } else {
//         icon = Icons.notifications_active;
//         eventType = 'Reminder';
//         subtitleText = note.isNotEmpty ? note : 'Reminder set';
        
//         // Color coding based on urgency for upcoming reminders
//         if (days == 0) {
//           bgColor = Colors.red.shade100;
//           textColor = Colors.red.shade900;
//         } else if (days <= 2) {
//           bgColor = Colors.orange.shade100;
//           textColor = Colors.orange.shade900;
//         } else if (days <= 4) {
//           bgColor = Colors.amber.shade100;
//           textColor = Colors.amber.shade900;
//         } else {
//           bgColor = Colors.green.shade100;
//           textColor = Colors.green.shade800;
//         }
//       }
//     } else if (isBirthday) {
//       icon = Icons.cake;
//       eventType = 'Birthday';
//       subtitleText = '$eventType · ${_daysLabel(days)}';
      
//       if (days == 0) {
//         bgColor = Colors.pink.shade100;
//         textColor = Colors.pink.shade900;
//       } else if (days <= 2) {
//         bgColor = Colors.orange.shade100;
//         textColor = Colors.orange.shade900;
//       } else if (days <= 4) {
//         bgColor = Colors.amber.shade100;
//         textColor = Colors.amber.shade900;
//       } else {
//         bgColor = Colors.green.shade100;
//         textColor = Colors.green.shade800;
//       }
//     } else {
//       icon = Icons.favorite;
//       eventType = 'Anniversary';
//       subtitleText = '$eventType · ${_daysLabel(days)}';
      
//       if (days == 0) {
//         bgColor = Colors.purple.shade100;
//         textColor = Colors.purple.shade900;
//       } else if (days <= 2) {
//         bgColor = Colors.orange.shade100;
//         textColor = Colors.orange.shade900;
//       } else if (days <= 4) {
//         bgColor = Colors.amber.shade100;
//         textColor = Colors.amber.shade900;
//       } else {
//         bgColor = Colors.blue.shade100;
//         textColor = Colors.blue.shade800;
//       }
//     }

//     final dayLabel = _daysLabel(days, isOverdue: isOverdue);

//     return Card(
//       margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
//       elevation: 2,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       child: ListTile(
//         leading: CircleAvatar(
//           backgroundColor: bgColor,
//           child: Icon(icon, color: textColor),
//         ),
//         title: Row(
//           children: [
//             Expanded(
//               child: Text(
//                 name,
//                 style: const TextStyle(fontWeight: FontWeight.w600),
//                 overflow: TextOverflow.ellipsis,
//               ),
//             ),
//             if (isOverdue)
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
//                 decoration: BoxDecoration(
//                   color: Colors.red,
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: const Text(
//                   'OVERDUE',
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 10,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ),
//           ],
//         ),
//         subtitle: Text(
//           subtitleText,
//           maxLines: 2,
//           overflow: TextOverflow.ellipsis,
//         ),
//         trailing: Container(
//           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
//           decoration: BoxDecoration(
//             color: bgColor,
//             borderRadius: BorderRadius.circular(20),
//           ),
//           child: Text(
//             dayLabel,
//             style: TextStyle(
//               fontWeight: FontWeight.bold,
//               color: textColor,
//               fontSize: 12,
//             ),
//           ),
//         ),
//         onTap: () {
//           // Show reminder details on tap
//           if (isReminder) {
//             _showReminderDetails(event);
//           } else {
//             // For birthdays/anniversaries, show a simple dialog with info
//             showDialog(
//               context: context,
//               builder: (context) => AlertDialog(
//                 title: Text(
//                   isBirthday ? '🎂 Birthday' : '💍 Anniversary',
//                   style: const TextStyle(fontWeight: FontWeight.w600),
//                 ),
//                 content: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       'Customer: $name',
//                       style: const TextStyle(fontSize: 16),
//                     ),
//                     const SizedBox(height: 8),
//                     Text(
//                       'Date: ${_daysLabel(days)}',
//                       style: const TextStyle(fontSize: 14),
//                     ),
//                     if (customer['phone'] != null) ...[
//                       const SizedBox(height: 8),
//                       Text(
//                         'Phone: ${customer['phone']}',
//                         style: const TextStyle(fontSize: 14),
//                       ),
//                     ],
//                   ],
//                 ),
//                 actions: [
//                   TextButton(
//                     onPressed: () => Navigator.pop(context),
//                     child: const Text('Close'),
//                   ),
//                 ],
//               ),
//             );
//           }
//         },
//       ),
//     );
//   }

//   // ---- Build the screen ----
//   @override
//   Widget build(BuildContext context) {
//     final events = _buildUpcomingEvents();

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Reminders'),
//         backgroundColor: Colors.white,
//         foregroundColor: AppColors.textPrimary,
//         elevation: 0,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back),
//           onPressed: () => Navigator.pop(context),
//         ),
//         actions: [
//           if (events.any((e) => e['isOverdue'] == true))
//             IconButton(
//               icon: const Icon(Icons.check_circle_outline, color: Colors.red),
//               onPressed: () {
//                 // Option to mark all overdue as completed
//                 _showMarkAllCompletedDialog(events);
//               },
//             ),
//         ],
//       ),
//       body: events.isEmpty
//           ? _buildEmptyState()
//           : ListView.builder(
//               padding: const EdgeInsets.symmetric(vertical: 8),
//               itemCount: events.length,
//               itemBuilder: (ctx, index) =>
//                   _buildEventTile(events[index], context),
//             ),
//     );
//   }

//   // ---- Mark all overdue reminders as completed ----
//   void _showMarkAllCompletedDialog(List<Map<String, dynamic>> events) {
//     final overdueEvents = events.where((e) => e['isOverdue'] == true).toList();
//     if (overdueEvents.isEmpty) return;

//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Mark All Overdue as Completed?'),
//         content: Text(
//           'This will mark ${overdueEvents.length} overdue reminder(s) as completed.',
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Cancel'),
//           ),
//           TextButton(
//             onPressed: () async {
//               Navigator.pop(context);
              
//               // Show loading
//               setState(() {});
              
//               int successCount = 0;
//               int failCount = 0;
              
//               for (var event in overdueEvents) {
//                 final customerId = event['customerId']?.toString();
//                 if (customerId != null) {
//                   try {
//                     final result = await ApiService().markReminderCompleted(customerId);
//                     if (result['success'] == true) {
//                       successCount++;
//                     } else {
//                       failCount++;
//                     }
//                   } catch (_) {
//                     failCount++;
//                   }
//                 }
//               }
              
//               // Refresh
//               setState(() {});
              
//               ScaffoldMessenger.of(context).showSnackBar(
//                 SnackBar(
//                   content: Text(
//                     '$successCount reminders completed${failCount > 0 ? ', $failCount failed' : ''}',
//                   ),
//                   backgroundColor: failCount > 0 ? Colors.orange : Colors.green,
//                 ),
//               );
//             },
//             child: const Text(
//               'Complete All',
//               style: TextStyle(color: Colors.green),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildEmptyState() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(
//             Icons.event_busy,
//             size: 80,
//             color: Colors.grey.shade400,
//           ),
//           const SizedBox(height: 16),
//           Text(
//             'No reminders or events',
//             style: TextStyle(
//               fontSize: 18,
//               fontWeight: FontWeight.w600,
//               color: Colors.grey.shade700,
//             ),
//           ),
//           const SizedBox(height: 8),
//           Text(
//             'Set reminders for customers to get notified.',
//             style: TextStyle(
//               fontSize: 14,
//               color: Colors.grey.shade500,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }


import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class RemindersScreen extends StatefulWidget {
  final List<Map<String, dynamic>> customers;
  final Map<String, dynamic> user;

  const RemindersScreen({
    Key? key,
    required this.customers,
    required this.user,
  }) : super(key: key);

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  @override
  void initState() {
    super.initState();
    // NOTE: NotificationService().init(navigatorKey) must already have run
    // once at app startup (it needs the app-wide navigatorKey, which this
    // screen doesn't have). This screen only needs to (re)sync scheduling.
    // resyncPendingReminders() schedules an exact OS notification for every
    // future pending reminder, fires one immediately (once) for anything
    // already overdue, and skips anything already scheduled/notified - so
    // no in-screen polling timer is needed; the OS fires it at the right time.
    NotificationService().resyncPendingReminders(widget.customers);
  }

  @override
  void didUpdateWidget(covariant RemindersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.customers != widget.customers) {
      NotificationService().resyncPendingReminders(widget.customers);
    }
  }

  /// Normalizes a customer's `reminder` field (single map or list) into a
  /// mutable List<Map> that still references the *original* objects, so
  /// edits (like marking complete) persist back onto widget.customers.
  List<Map<String, dynamic>> _remindersOf(Map<String, dynamic> customer) {
    final reminderData = customer['reminder'];
    if (reminderData is List) {
      return reminderData.cast<Map<String, dynamic>>();
    } else if (reminderData is Map) {
      return [reminderData.cast<String, dynamic>()];
    }
    return [];
  }

  // ---- Reuse the same date parser from CustomerListScreen ----
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

  // Parse ISO datetime string to DateTime
  DateTime? _parseDateTime(String dateTimeStr) {
    try {
      return DateTime.parse(dateTimeStr);
    } catch (_) {
      return null;
    }
  }

  // ---- Build the list of upcoming events (including reminders) ----
  List<Map<String, dynamic>> _buildUpcomingEvents() {
    final List<Map<String, dynamic>> events = [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (var customer in widget.customers) {
      final name = (customer['name'] ?? '').toString();

      // Helper to add birthday/anniversary events
      void addEvent(String? dateString, bool isBirthday) {
        if (dateString == null || dateString.isEmpty) return;
        final parsed = _parseDate(dateString);
        if (parsed == null) return;

        final (month, day) = parsed;
        DateTime eventDate = DateTime(now.year, month, day);
        if (eventDate.compareTo(today) < 0) {
          eventDate = DateTime(now.year + 1, month, day);
        }

        final diff = eventDate.difference(today).inDays;
        if (diff >= 0 && diff <= 7) {
          events.add({
            'customerName': name,
            'customerId': customer['_id'],
            'date': eventDate,
            'daysRemaining': diff,
            'isBirthday': isBirthday,
            'isReminder': false,
            'customer': customer,
          });
        }
      }

      // --- Add birthday and anniversary ---
      addEvent(customer['birthday'], true);
      addEvent(customer['anniversary'], false);

      // --- Add reminders from customer ---
      final reminders = _remindersOf(customer);

      for (var reminder in reminders) {
        // Only show reminders that are still pending. Once completed
        // (via the mark-as-read button, the dialog, or "complete all"),
        // they're filtered out here and disappear from the page.
        if (reminder['status'] != 'pending') continue;

        final dateStr = reminder['date'];
        if (dateStr == null || dateStr.isEmpty) continue;

        // Parse the reminder date (ISO format with time)
        DateTime? reminderDateTime = _parseDateTime(dateStr);
        if (reminderDateTime == null) continue;

        // Convert to local time for comparison
        final localReminderTime = reminderDateTime.toLocal();

        // Calendar-day difference (used only for the "Today/Tomorrow/
        // In X days" label), computed from midnight-to-midnight so it's
        // exact - no truncation surprises.
        final eventDate = DateTime(
          localReminderTime.year,
          localReminderTime.month,
          localReminderTime.day,
        );
        final diff = eventDate.difference(today).inDays;

        // Show reminders from 7 days overdue up to 7 days in the future.
        if (diff < -7 || diff > 7) continue;

        // 🔥 FIX: overdue is based on the exact date+time, not just the
        // calendar day. A reminder set for 12:00pm today is overdue the
        // moment it's past 12:00pm today (e.g. it's 11:00pm) - it no
        // longer waits for the day to fully roll over.
        final isOverdue = localReminderTime.isBefore(now);

        events.add({
          'customerName': name,
          'customerId': customer['_id'],
          'date': eventDate,
          'time': localReminderTime,
          'daysRemaining': diff,
          'isBirthday': false,
          'isReminder': true,
          'note': reminder['note'] ?? '',
          'customer': customer,
          'reminderData': reminder,
          'isOverdue': isOverdue,
          'reminderDateTime': localReminderTime,
        });
      }
    }

    // Sort by days remaining (soonest first, with overdue at the top)
    events.sort((a, b) {
      // Show overdue reminders first (negative days)
      final aOverdue = a['isOverdue'] ?? false;
      final bOverdue = b['isOverdue'] ?? false;

      if (aOverdue && !bOverdue) return -1;
      if (!aOverdue && bOverdue) return 1;

      // Then sort by days remaining
      return a['daysRemaining'].compareTo(b['daysRemaining']);
    });

    return events;
  }

  // Helper for day label with overdue handling
  String _daysLabel(int days, {bool isOverdue = false}) {
    if (isOverdue) {
      final overdueDays = days.abs();
      if (overdueDays == 0) return 'Overdue - Today';
      if (overdueDays == 1) return 'Overdue - Yesterday';
      return 'Overdue - $overdueDays days ago';
    }
    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    return 'In $days days';
  }

  // ---- Shared completion logic used by the inline button, the details
  // dialog, and "complete all" ----
  Future<void> _completeReminder(Map<String, dynamic> event) async {
    final customerId = event['customerId']?.toString();
    if (customerId == null) return;

    try {
      final result = await ApiService().markReminderCompleted(customerId);
      if (result['success'] == true) {
        // Mutate the actual reminder object in widget.customers so it
        // immediately drops out of _buildUpcomingEvents(), no refetch needed.
        final reminder = event['reminderData'];
        if (reminder is Map) {
          reminder['status'] = 'completed';
        }

        // Cancel any pending OS notification for this reminder.
        final reminderDateTime = event['reminderDateTime'] as DateTime?;
        if (reminderDateTime != null) {
          NotificationService().cancelReminder(customerId, reminderDateTime);
        }

        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reminder marked as completed!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${result['message'] ?? 'Failed to update'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ---- Show reminder details dialog ----
  void _showReminderDetails(Map<String, dynamic> event) {
    final isOverdue = event['isOverdue'] ?? false;
    final days = event['daysRemaining'];
    final name = event['customerName'];
    final note = event['note'] ?? 'No note provided';
    final reminderDateTime = event['reminderDateTime'] as DateTime?;
    final customer = event['customer'] as Map<String, dynamic>;

    // Format the date and time
    String formattedDateTime = 'Not set';
    if (reminderDateTime != null) {
      formattedDateTime =
          '${reminderDateTime.year}-${reminderDateTime.month.toString().padLeft(2, '0')}-${reminderDateTime.day.toString().padLeft(2, '0')} '
          '${reminderDateTime.hour.toString().padLeft(2, '0')}:${reminderDateTime.minute.toString().padLeft(2, '0')}';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isOverdue ? Icons.warning_amber_rounded : Icons.notifications_active,
              color: isOverdue ? Colors.red : AppColors.primary,
            ),
            const SizedBox(width: 8),
            Text(isOverdue ? 'Overdue Reminder' : 'Reminder Details'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Customer name
              _buildDetailRow('Customer', name),
              const SizedBox(height: 8),

              // Date & Time
              _buildDetailRow('Date & Time', formattedDateTime),
              const SizedBox(height: 8),

              // Status
              _buildDetailRow(
                'Status',
                isOverdue ? '⚠️ Overdue' : '✅ Upcoming',
              ),
              const SizedBox(height: 8),

              // Days
              _buildDetailRow(
                'Days',
                _daysLabel(days, isOverdue: isOverdue),
              ),
              const SizedBox(height: 8),

              // Note
              const Divider(),
              const Text(
                'Note:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                note,
                style: const TextStyle(fontSize: 14),
              ),

              // Phone number if available
              if (customer['phone'] != null) ...[
                const SizedBox(height: 8),
                const Divider(),
                _buildDetailRow(
                  'Phone',
                  customer['phone'].toString(),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showMarkCompletedDialog(event);
            },
            child: const Text(
              'Mark as Completed',
              style: TextStyle(color: Colors.green),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Mark reminder as completed (confirmation dialog) ----
  void _showMarkCompletedDialog(Map<String, dynamic> event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Completed?'),
        content: const Text(
          'Are you sure you want to mark this reminder as completed? '
          'It will be removed from the reminders list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close the dialog
              _completeReminder(event);
            },
            child: const Text(
              'Yes, Complete',
              style: TextStyle(color: Colors.green),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  // ---- Build a single event tile ----
  Widget _buildEventTile(Map<String, dynamic> event, BuildContext context) {
    final isBirthday = event['isBirthday'] ?? false;
    final isReminder = event['isReminder'] ?? false;
    final isOverdue = event['isOverdue'] ?? false;
    final days = event['daysRemaining'];
    final name = event['customerName'];
    final customer = event['customer'] as Map<String, dynamic>;
    final note = event['note'] ?? '';

    // Colour & icon
    Color bgColor;
    Color textColor;
    IconData icon;
    String eventType;
    String subtitleText;

    if (isReminder) {
      if (isOverdue) {
        icon = Icons.warning_amber_rounded;
        eventType = 'OVERDUE Reminder';
        subtitleText = '⚠️ ${_daysLabel(days, isOverdue: true)}';
        bgColor = Colors.red.shade100;
        textColor = Colors.red.shade900;
      } else {
        icon = Icons.notifications_active;
        eventType = 'Reminder';
        subtitleText = note.isNotEmpty ? note : 'Reminder set';

        // Color coding based on urgency for upcoming reminders
        if (days == 0) {
          bgColor = Colors.red.shade100;
          textColor = Colors.red.shade900;
        } else if (days <= 2) {
          bgColor = Colors.orange.shade100;
          textColor = Colors.orange.shade900;
        } else if (days <= 4) {
          bgColor = Colors.amber.shade100;
          textColor = Colors.amber.shade900;
        } else {
          bgColor = Colors.green.shade100;
          textColor = Colors.green.shade800;
        }
      }
    } else if (isBirthday) {
      icon = Icons.cake;
      eventType = 'Birthday';
      subtitleText = '$eventType · ${_daysLabel(days)}';

      if (days == 0) {
        bgColor = Colors.pink.shade100;
        textColor = Colors.pink.shade900;
      } else if (days <= 2) {
        bgColor = Colors.orange.shade100;
        textColor = Colors.orange.shade900;
      } else if (days <= 4) {
        bgColor = Colors.amber.shade100;
        textColor = Colors.amber.shade900;
      } else {
        bgColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
      }
    } else {
      icon = Icons.favorite;
      eventType = 'Anniversary';
      subtitleText = '$eventType · ${_daysLabel(days)}';

      if (days == 0) {
        bgColor = Colors.purple.shade100;
        textColor = Colors.purple.shade900;
      } else if (days <= 2) {
        bgColor = Colors.orange.shade100;
        textColor = Colors.orange.shade900;
      } else if (days <= 4) {
        bgColor = Colors.amber.shade100;
        textColor = Colors.amber.shade900;
      } else {
        bgColor = Colors.blue.shade100;
        textColor = Colors.blue.shade800;
      }
    }

    final dayLabel = _daysLabel(days, isOverdue: isOverdue);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: bgColor,
          child: Icon(icon, color: textColor),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isOverdue)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'OVERDUE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          subtitleText,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                dayLabel,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  fontSize: 12,
                ),
              ),
            ),
            // 🔥 NEW: Mark-as-read/complete button, right on the tile, for
            // every reminder (not just overdue ones). Tapping it marks the
            // reminder completed and it disappears from this list.
            if (isReminder)
              IconButton(
                tooltip: 'Mark as read / complete',
                icon: const Icon(Icons.check_circle_outline),
                color: Colors.green,
                onPressed: () => _confirmMarkAsRead(event),
              ),
          ],
        ),
        onTap: () {
          // Show reminder details on tap
          if (isReminder) {
            _showReminderDetails(event);
          } else {
            // For birthdays/anniversaries, show a simple dialog with info
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(
                  isBirthday ? '🎂 Birthday' : '💍 Anniversary',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customer: $name',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Date: ${_daysLabel(days)}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    if (customer['phone'] != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Phone: ${customer['phone']}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  // Quick confirm before the inline mark-as-read button actually completes it.
  void _confirmMarkAsRead(Map<String, dynamic> event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Read?'),
        content: Text(
          'Mark the reminder for "${event['customerName']}" as complete? '
          'It will be removed from this list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _completeReminder(event);
            },
            child: const Text(
              'Mark as Read',
              style: TextStyle(color: Colors.green),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Build the screen ----
  @override
  Widget build(BuildContext context) {
    final events = _buildUpcomingEvents();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (events.any((e) => e['isOverdue'] == true))
            IconButton(
              icon: const Icon(Icons.check_circle_outline, color: Colors.red),
              onPressed: () {
                // Option to mark all overdue as completed
                _showMarkAllCompletedDialog(events);
              },
            ),
        ],
      ),
      body: events.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: events.length,
              itemBuilder: (ctx, index) =>
                  _buildEventTile(events[index], context),
            ),
    );
  }

  // ---- Mark all overdue reminders as completed ----
  void _showMarkAllCompletedDialog(List<Map<String, dynamic>> events) {
    final overdueEvents = events.where((e) => e['isOverdue'] == true).toList();
    if (overdueEvents.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark All Overdue as Completed?'),
        content: Text(
          'This will mark ${overdueEvents.length} overdue reminder(s) as completed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              int successCount = 0;
              int failCount = 0;

              for (var event in overdueEvents) {
                final customerId = event['customerId']?.toString();
                if (customerId != null) {
                  try {
                    final result = await ApiService().markReminderCompleted(customerId);
                    if (result['success'] == true) {
                      final reminder = event['reminderData'];
                      if (reminder is Map) {
                        reminder['status'] = 'completed';
                      }
                      final reminderDateTime = event['reminderDateTime'] as DateTime?;
                      if (reminderDateTime != null) {
                        NotificationService().cancelReminder(customerId, reminderDateTime);
                      }
                      successCount++;
                    } else {
                      failCount++;
                    }
                  } catch (_) {
                    failCount++;
                  }
                }
              }

              // Refresh
              if (mounted) {
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '$successCount reminders completed${failCount > 0 ? ', $failCount failed' : ''}',
                    ),
                    backgroundColor: failCount > 0 ? Colors.orange : Colors.green,
                  ),
                );
              }
            },
            child: const Text(
              'Complete All',
              style: TextStyle(color: Colors.green),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No reminders or events',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Set reminders for customers to get notified.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}