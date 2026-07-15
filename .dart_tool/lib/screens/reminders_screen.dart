import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class RemindersScreen extends StatelessWidget {
  final List<Map<String, dynamic>> customers;
  final Map<String, dynamic> user;

  const RemindersScreen({
    Key? key,
    required this.customers,
    required this.user,
  }) : super(key: key);

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

  // ---- Build the list of upcoming events ----
  // List<Map<String, dynamic>> _buildUpcomingEvents() {
  //   final List<Map<String, dynamic>> events = [];
  //   final now = DateTime.now();
  //   final today = DateTime(now.year, now.month, now.day);

  //   for (var customer in customers) {
  //     final name = (customer['name'] ?? '').toString();

  //     void addEvent(String? dateString, bool isBirthday) {
  //       if (dateString == null || dateString.isEmpty) return;
  //       final parsed = _parseDate(dateString);
  //       if (parsed == null) return;

  //       final (month, day) = parsed;
  //       DateTime eventDate = DateTime(now.year, month, day);
  //       if (eventDate.compareTo(today) < 0) {
  //         eventDate = DateTime(now.year + 1, month, day);
  //       }

  //       final diff = eventDate.difference(today).inDays;
  //       if (diff >= 0 && diff <= 7) {
  //         events.add({
  //           'customerName': name,
  //           'customerId': customer['_id'],
  //           'date': eventDate,
  //           'daysRemaining': diff,
  //           'isBirthday': isBirthday,
  //           'customer': customer,
  //         });
  //       }
  //     }

  //     addEvent(customer['birthday'], true);
  //     addEvent(customer['anniversary'], false);
  //   }

  //   // Sort by days remaining (soonest first)
  //   events.sort((a, b) => a['daysRemaining'].compareTo(b['daysRemaining']));
  //   return events;
  // }
  // ---- Build the list of upcoming events (including reminders) ----
List<Map<String, dynamic>> _buildUpcomingEvents() {
  final List<Map<String, dynamic>> events = [];
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  for (var customer in customers) {
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
    final reminderData = customer['reminder'];
    if (reminderData != null) {
      // If it's a list, iterate; if it's a single map, treat as list of one
      List reminders = [];
      if (reminderData is List) {
        reminders = reminderData;
      } else if (reminderData is Map) {
        reminders = [reminderData];
      }

      for (var reminder in reminders) {
        // Only include pending reminders (you can also choose to show all)
        if (reminder['status'] != 'pending') continue;

        final dateStr = reminder['date'];
        if (dateStr == null || dateStr.isEmpty) continue;

        // Parse the reminder date (ISO format)
        final parsed = _parseDate(dateStr);
        if (parsed == null) continue;

        final (month, day) = parsed;
        DateTime eventDate = DateTime(now.year, month, day);
        // If the date is in the past, assume it's for next year
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
            'isBirthday': false,
            'isReminder': true,
            'note': reminder['note'] ?? '',
            'customer': customer,
          });
        }
      }
    }
  }

  // Sort by days remaining (soonest first)
  events.sort((a, b) => a['daysRemaining'].compareTo(b['daysRemaining']));
  return events;
}

// ---- Build a single event tile (supports birthdays, anniversaries, and reminders) ----
Widget _buildEventTile(Map<String, dynamic> event, BuildContext context) {
  final isBirthday = event['isBirthday'] ?? false;
  final isReminder = event['isReminder'] ?? false;
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
    icon = Icons.notifications_active;
    eventType = 'Reminder';
    subtitleText = note.isNotEmpty ? note : 'Reminder set';
  } else if (isBirthday) {
    icon = Icons.cake;
    eventType = 'Birthday';
    subtitleText = '$eventType · ${_daysLabel(days)}';
  } else {
    icon = Icons.favorite;
    eventType = 'Anniversary';
    subtitleText = '$eventType · ${_daysLabel(days)}';
  }

  // Color coding based on urgency
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

  final dayLabel = _daysLabel(days);

  return Card(
    margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: bgColor,
        child: Icon(icon, color: textColor),
      ),
      title: Text(
        name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        isReminder ? subtitleText : '$eventType · $dayLabel',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Container(
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
      onTap: () {
        // Optional: navigate to customer detail / edit screen
        // You can use Navigator.push to go to a CustomerDetailScreen
      },
    ),
  );
}

// Helper for day label
String _daysLabel(int days) {
  if (days == 0) return 'Today';
  if (days == 1) return 'Tomorrow';
  return 'In $days days';
}

  // ---- Build a single event tile ----
  Widget _buildEventTile(Map<String, dynamic> event, BuildContext context) {
    final isBirthday = event['isBirthday'];
    final days = event['daysRemaining'];
    final name = event['customerName'];
    final customer = event['customer'] as Map<String, dynamic>;

    // Colour & icon
    Color bgColor;
    Color textColor;
    IconData icon;
    String eventType;

    if (isBirthday) {
      icon = Icons.cake;
      eventType = 'Birthday';
    } else {
      icon = Icons.favorite;
      eventType = 'Anniversary';
    }

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

    final dayLabel = days == 0
        ? 'Today'
        : days == 1
            ? 'Tomorrow'
            : 'In $days days';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: bgColor,
          child: Icon(icon, color: textColor),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('$eventType · $dayLabel'),
        trailing: Container(
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
        onTap: () {
          // Optional: navigate to customer edit screen
          // You can pass the customer to edit, but for now just pop
        },
      ),
    );
  }

  // ---- Build the screen ----
  @override
  Widget build(BuildContext context) {
    final events = _buildUpcomingEvents();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upcoming Reminders'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
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
            'No upcoming birthdays or anniversaries',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We\'ll notify you when something is coming up.',
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