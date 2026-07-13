// // screens/notification_screen.dart
// import 'package:flutter/material.dart';
// import '../theme/app_theme.dart';
// import '../services/api_service.dart';
// import '../services/notification_service.dart';
// import 'add_customer_screen.dart';

// class NotificationScreen extends StatefulWidget {
//   const NotificationScreen({Key? key}) : super(key: key);

//   @override
//   State<NotificationScreen> createState() => _NotificationScreenState();
// }

// class _NotificationScreenState extends State<NotificationScreen> {
//   List<Map<String, dynamic>> _notifications = [];
//   bool _isLoading = true;
//   String? _error;
//   int _unreadCount = 0;

//   final NotificationService _notificationService = NotificationService();

//   @override
//   void initState() {
//     super.initState();
//     _loadNotifications();
//   }

//   Future<void> _loadNotifications() async {
//     setState(() {
//       _isLoading = true;
//       _error = null;
//     });

//     try {
//       final apiService = ApiService();
//       final response = await apiService.getNotifications(limit: 50);

//       if (response['success'] == true) {
//         final data = response['data'];
//         final notifications = data['notifications'] as List? ?? [];

//         if (mounted) {
//           setState(() {
//             _notifications = List<Map<String, dynamic>>.from(notifications);
//             // 👇 Auto-seen: as soon as this screen opens, everything is
//             // treated as read in the UI immediately. No separate "unread"
//             // styling window, no manual button needed.
//             for (var n in _notifications) {
//               n['isRead'] = true;
//             }
//             _unreadCount = 0;
//             _isLoading = false;
//           });
//         }

//         // Tell the backend too, so the dashboard badge is correct.
//         _markAllAsReadSilently();
//       } else {
//         if (mounted) {
//           setState(() {
//             _error = response['message'] ?? 'Failed to load notifications';
//             _isLoading = false;
//           });
//         }
//       }
//     } catch (e) {
//       if (mounted) {
//         setState(() {
//           _error = 'Error: $e';
//           _isLoading = false;
//         });
//       }
//     }
//   }

//   // Silent version — no snackbar, no UI flip. Just tells the backend so
//   // the dashboard badge is correct next time. The current list keeps
//   // showing items as "unread-styled" until the user leaves this screen.
//   Future<void> _markAllAsReadSilently() async {
//     try {
//       final apiService = ApiService();
//       await apiService.markAllNotificationsAsRead();
//     } catch (e) {
//       print('❌ Error silently marking all as read: $e');
//     }
//   }

//   Future<void> _markAsRead(String notificationId) async {
//     try {
//       final apiService = ApiService();
//       await apiService.markNotificationAsRead(notificationId);
      
//       // Update local state
//       setState(() {
//         final index = _notifications.indexWhere((n) => n['_id'] == notificationId);
//         if (index != -1) {
//           _notifications[index]['isRead'] = true;
//           _notifications[index]['readAt'] = DateTime.now().toIso8601String();
//         }
//         _unreadCount = _notifications.where((n) => n['isRead'] != true).length;
//       });
//     } catch (e) {
//       print('❌ Error marking as read: $e');
//     }
//   }

//   Future<void> _markAllAsRead() async {
//     try {
//       final apiService = ApiService();
//       final response = await apiService.markAllNotificationsAsRead();
      
//       if (response['success'] == true) {
//         setState(() {
//           for (var notification in _notifications) {
//             notification['isRead'] = true;
//           }
//           _unreadCount = 0;
//         });
        
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(
//               content: Text('All notifications marked as read'),
//               backgroundColor: Colors.green,
//             ),
//           );
//         }
//       }
//     } catch (e) {
//       print('❌ Error marking all as read: $e');
//     }
//   }

//   Future<void> _deleteNotification(String notificationId, int index) async {
//     try {
//       final apiService = ApiService();
//       final response = await apiService.deleteNotification(notificationId);
      
//       if (response['success'] == true) {
//         setState(() {
//           _notifications.removeAt(index);
//           _unreadCount = _notifications.where((n) => n['isRead'] != true).length;
//         });
//       }
//     } catch (e) {
//       print('❌ Error deleting notification: $e');
//     }
//   }

//   void _onNotificationTap(Map<String, dynamic> notification) async {
//     final notificationId = notification['_id']?.toString();
//     if (notificationId != null && notification['isRead'] != true) {
//       await _markAsRead(notificationId);
//     }

//     final customerId = notification['customerId'];
//     final customerIdStr = customerId is Map
//         ? customerId['_id']?.toString()
//         : customerId?.toString();

//     // 👇 For reminder notifications: once opened, the reminder is done.
//     // Mark it complete on the specific visit (clears reminder.date/note there),
//     // and remove this notification from the list right away so it can't
//     // pop up again.
//     final type = notification['type']?.toString();
//     if (type == 'reminder' && customerIdStr != null) {
//       try {
//         // Get the visit number from the notification data
//         // The visit number should be stored in the notification when created
//         final visitNumber = notification['visitNumber'] ?? 1;
        
//         final apiService = ApiService();
//         // ✅ UPDATED: Use completeVisitReminder instead of completeReminder
//         await apiService.completeVisitReminder(
//           customerIdStr, 
//           visitNumber is int ? visitNumber : int.tryParse(visitNumber.toString()) ?? 1
//         );
        
//         setState(() {
//           _notifications.removeWhere((n) => n['_id'] == notificationId);
//         });
//       } catch (e) {
//         print('❌ Error completing visit reminder: $e');
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text('Error completing reminder: $e'),
//               backgroundColor: Colors.red,
//             ),
//           );
//         }
//       }
//     }

//     if (customerIdStr != null && mounted) {
//       try {
//         final apiService = ApiService();
//         final response = await apiService.getCustomerById(customerIdStr);

//         if (response['success'] == true && mounted) {
//           final customer = response['data'] as Map<String, dynamic>;

//           Navigator.push(
//             context,
//             MaterialPageRoute(
//               builder: (_) => AddCustomerScreen(
//                 employees: [],
//                 customers: [],
//                 customerToEdit: customer,
//               ),
//             ),
//           );
//         }
//       } catch (e) {
//         print('❌ Error navigating to customer: $e');
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text('Could not load customer details: $e'),
//               backgroundColor: Colors.red,
//             ),
//           );
//         }
//       }
//     }
//   }

//   String _formatTime(String? dateString) {
//     if (dateString == null) return '';
    
//     try {
//       final date = DateTime.parse(dateString);
//       final now = DateTime.now();
//       final difference = now.difference(date);

//       if (difference.inMinutes < 1) {
//         return 'Just now';
//       } else if (difference.inMinutes < 60) {
//         return '${difference.inMinutes}m ago';
//       } else if (difference.inHours < 24) {
//         return '${difference.inHours}h ago';
//       } else if (difference.inDays < 7) {
//         return '${difference.inDays}d ago';
//       } else {
//         return '${date.day}/${date.month}/${date.year}';
//       }
//     } catch (e) {
//       return dateString ?? '';
//     }
//   }

//   IconData _getNotificationIcon(String? type) {
//     switch (type) {
//       case 'birthday':
//         return Icons.cake;
//       case 'anniversary':
//         return Icons.favorite;
//       case 'reminder':
//         return Icons.alarm;
//       default:
//         return Icons.notifications;
//     }
//   }

//   Color _getNotificationColor(String? type) {
//     switch (type) {
//       case 'birthday':
//         return Colors.pink;
//       case 'anniversary':
//         return Colors.purple;
//       case 'reminder':
//         return Colors.orange;
//       default:
//         return AppColors.primary;
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         elevation: 0,
//         backgroundColor: Colors.white,
//         foregroundColor: AppColors.textPrimary,
//         title: Row(
//           children: [
//             const Text(
//               'Notifications',
//               style: TextStyle(fontWeight: FontWeight.w700),
//             ),
//             if (_unreadCount > 0) ...[
//               const SizedBox(width: 8),
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
//                 decoration: BoxDecoration(
//                   color: Colors.red,
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: Text(
//                   '$_unreadCount',
//                   style: const TextStyle(
//                     color: Colors.white,
//                     fontSize: 12,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ),
//             ],
//           ],
//         ),
//         actions: [
//           if (_notifications.isNotEmpty && _unreadCount > 0)
//             TextButton(
//               onPressed: _markAllAsRead,
//               child: const Text(
//                 'Mark all read',
//                 style: TextStyle(
//                   fontSize: 13,
//                   fontWeight: FontWeight.w600,
//                   color: AppColors.primary,
//                 ),
//               ),
//             ),
//           IconButton(
//             icon: const Icon(Icons.refresh),
//             onPressed: _loadNotifications,
//             tooltip: 'Refresh',
//           ),
//         ],
//       ),
//       body: _isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : _error != null
//               ? Center(
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
//                       const SizedBox(height: 16),
//                       Text(
//                         _error!,
//                         style: TextStyle(color: Colors.grey[600]),
//                         textAlign: TextAlign.center,
//                       ),
//                       const SizedBox(height: 16),
//                       ElevatedButton(
//                         onPressed: _loadNotifications,
//                         child: const Text('Retry'),
//                       ),
//                     ],
//                   ),
//                 )
//               : _notifications.isEmpty
//                   ? Center(
//                       child: Column(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           Icon(
//                             Icons.notifications_none,
//                             size: 64,
//                             color: Colors.grey[400],
//                           ),
//                           const SizedBox(height: 16),
//                           Text(
//                             'No notifications yet',
//                             style: TextStyle(
//                               fontSize: 16,
//                               color: Colors.grey[600],
//                             ),
//                           ),
//                           const SizedBox(height: 8),
//                           Text(
//                             'Birthday reminders, anniversary alerts, and more will appear here',
//                             style: TextStyle(
//                               fontSize: 13,
//                               color: Colors.grey[500],
//                             ),
//                             textAlign: TextAlign.center,
//                           ),
//                         ],
//                       ),
//                     )
//                   : RefreshIndicator(
//                       onRefresh: _loadNotifications,
//                       child: ListView.builder(
//                         padding: const EdgeInsets.all(16),
//                         itemCount: _notifications.length,
//                         itemBuilder: (context, index) {
//                           final notification = _notifications[index];
//                           final type = notification['type']?.toString();
//                           final title = notification['title']?.toString() ?? 'Notification';
//                           final message = notification['message']?.toString() ?? '';
//                           final isRead = notification['isRead'] == true;
//                           final createdAt = notification['createdAt']?.toString();
//                           final customerName = notification['customerId'] is Map
//                               ? notification['customerId']['name']?.toString()
//                               : null;

//                           // Get visit number if available
//                           final visitNumber = notification['visitNumber'];
//                           final visitInfo = visitNumber != null 
//                               ? 'Visit #$visitNumber' 
//                               : '';

//                           return Dismissible(
//                             key: Key(notification['_id']?.toString() ?? index.toString()),
//                             direction: DismissDirection.endToStart,
//                             background: Container(
//                               alignment: Alignment.centerRight,
//                               padding: const EdgeInsets.only(right: 20),
//                               margin: const EdgeInsets.only(bottom: 10),
//                               decoration: BoxDecoration(
//                                 color: Colors.red,
//                                 borderRadius: BorderRadius.circular(12),
//                               ),
//                               child: const Icon(Icons.delete, color: Colors.white),
//                             ),
//                             onDismissed: (_) {
//                               _deleteNotification(
//                                 notification['_id']?.toString() ?? '',
//                                 index,
//                               );
//                             },
//                             child: GestureDetector(
//                               onTap: () => _onNotificationTap(notification),
//                               child: Container(
//                                 margin: const EdgeInsets.only(bottom: 10),
//                                 padding: const EdgeInsets.all(14),
//                                 decoration: BoxDecoration(
//                                   color: isRead ? Colors.white : Colors.blue.shade50,
//                                   borderRadius: BorderRadius.circular(12),
//                                   border: Border.all(
//                                     color: isRead 
//                                         ? AppColors.border.withOpacity(0.3) 
//                                         : AppColors.primary.withOpacity(0.3),
//                                   ),
//                                   boxShadow: [
//                                     BoxShadow(
//                                       color: Colors.grey.withOpacity(0.08),
//                                       blurRadius: 6,
//                                       offset: const Offset(0, 2),
//                                     ),
//                                   ],
//                                 ),
//                                 child: Row(
//                                   crossAxisAlignment: CrossAxisAlignment.start,
//                                   children: [
//                                     Container(
//                                       padding: const EdgeInsets.all(10),
//                                       decoration: BoxDecoration(
//                                         color: _getNotificationColor(type).withOpacity(0.1),
//                                         borderRadius: BorderRadius.circular(10),
//                                       ),
//                                       child: Icon(
//                                         _getNotificationIcon(type),
//                                         color: _getNotificationColor(type),
//                                         size: 22,
//                                       ),
//                                     ),
//                                     const SizedBox(width: 12),
//                                     Expanded(
//                                       child: Column(
//                                         crossAxisAlignment: CrossAxisAlignment.start,
//                                         children: [
//                                           Row(
//                                             children: [
//                                               Expanded(
//                                                 child: Text(
//                                                   title,
//                                                   style: TextStyle(
//                                                     fontWeight: isRead 
//                                                         ? FontWeight.w500 
//                                                         : FontWeight.w700,
//                                                     fontSize: 15,
//                                                     color: AppColors.textPrimary,
//                                                   ),
//                                                 ),
//                                               ),
//                                               if (!isRead)
//                                                 Container(
//                                                   width: 8,
//                                                   height: 8,
//                                                   decoration: const BoxDecoration(
//                                                     color: AppColors.primary,
//                                                     shape: BoxShape.circle,
//                                                   ),
//                                                 ),
//                                             ],
//                                           ),
//                                           const SizedBox(height: 4),
//                                           Text(
//                                             message,
//                                             style: TextStyle(
//                                               fontSize: 13,
//                                               color: AppColors.textSecondary,
//                                               height: 1.3,
//                                             ),
//                                             maxLines: 2,
//                                             overflow: TextOverflow.ellipsis,
//                                           ),
//                                           if (customerName != null) ...[
//                                             const SizedBox(height: 4),
//                                             Text(
//                                               '👤 $customerName${visitInfo.isNotEmpty ? ' ($visitInfo)' : ''}',
//                                               style: TextStyle(
//                                                 fontSize: 12,
//                                                 color: AppColors.primary,
//                                                 fontWeight: FontWeight.w500,
//                                               ),
//                                             ),
//                                           ],
//                                           const SizedBox(height: 6),
//                                           Text(
//                                             _formatTime(createdAt),
//                                             style: const TextStyle(
//                                               fontSize: 11,
//                                               color: AppColors.textSecondary,
//                                             ),
//                                           ),
//                                         ],
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                             ),
//                           );
//                         },
//                       ),
//                     ),
//     );
//   }
// }