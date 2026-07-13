const Notification = require('../models/Notification');
const Customer = require('../models/Customer');
const Employee = require('../models/Employee');

// Get all notifications for a user
exports.getNotifications = async (req, res) => {
  try {
    const userId = req.user._id;
    const { page = 1, limit = 20, type, isRead } = req.query;

    const filter = { userId };
    
    if (type) filter.type = type;
    if (isRead !== undefined) filter.isRead = isRead === 'true';

    const notifications = await Notification.find(filter)
      .populate('customerId', 'name phone')
      .sort({ date: -1, createdAt: -1 })
      .skip((page - 1) * limit)
      .limit(Number(limit));

    const total = await Notification.countDocuments(filter);
    const unreadCount = await Notification.countDocuments({ ...filter, isRead: false });

    res.json({
      success: true,
      data: {
        notifications,
        pagination: {
          total,
          unreadCount,
          page: Number(page),
          totalPages: Math.ceil(total / Number(limit))
        }
      }
    });
  } catch (err) {
    console.error("❌ Error getting notifications:", err);
    res.status(500).json({
      success: false,
      message: err.message || "Failed to get notifications"
    });
  }
};

// Mark notification as read
exports.markAsRead = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user._id;

    const notification = await Notification.findOneAndUpdate(
      { _id: id, userId },
      { 
        isRead: true, 
        readAt: new Date() 
      },
      { new: true }
    );

    if (!notification) {
      return res.status(404).json({
        success: false,
        message: "Notification not found"
      });
    }

    res.json({
      success: true,
      message: "Notification marked as read",
      data: notification
    });
  } catch (err) {
    console.error("❌ Error marking notification as read:", err);
    res.status(500).json({
      success: false,
      message: err.message || "Failed to mark notification as read"
    });
  }
};

// Mark all notifications as read
exports.markAllAsRead = async (req, res) => {
  try {
    const userId = req.user._id;

    await Notification.updateMany(
      { userId, isRead: false },
      { 
        isRead: true, 
        readAt: new Date() 
      }
    );

    res.json({
      success: true,
      message: "All notifications marked as read"
    });
  } catch (err) {
    console.error("❌ Error marking all notifications as read:", err);
    res.status(500).json({
      success: false,
      message: err.message || "Failed to mark notifications as read"
    });
  }
};

// Delete notification
exports.deleteNotification = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user._id;

    const notification = await Notification.findOneAndDelete({ _id: id, userId });

    if (!notification) {
      return res.status(404).json({
        success: false,
        message: "Notification not found"
      });
    }

    res.json({
      success: true,
      message: "Notification deleted"
    });
  } catch (err) {
    console.error("❌ Error deleting notification:", err);
    res.status(500).json({
      success: false,
      message: err.message || "Failed to delete notification"
    });
  }
};

// Create birthday/anniversary notifications (called by cron job)
exports.createSpecialDayNotifications = async () => {
  try {
    const today = new Date();
    const todayDay = today.getDate();
    const todayMonth = today.getMonth() + 1;
    
    // Get tomorrow's date for tomorrow notifications
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);
    const tomorrowDay = tomorrow.getDate();
    const tomorrowMonth = tomorrow.getMonth() + 1;

    // Get dates for next 7 days
    const next7Days = [];
    for (let i = 0; i <= 7; i++) {
      const date = new Date(today);
      date.setDate(date.getDate() + i);
      next7Days.push({
        day: date.getDate(),
        month: date.getMonth() + 1,
        daysAway: i
      });
    }

    // Get all employees
    const employees = await Employee.find({});
    
    for (const employee of employees) {
      // Find customers with birthdays in next 7 days
      for (const dateInfo of next7Days) {
        const birthdayStr = `${String(dateInfo.day).padStart(2, '0')}-${String(dateInfo.month).padStart(2, '0')}`;
        
        const birthdayCustomers = await Customer.find({
          birthday: birthdayStr
        });

        for (const customer of birthdayCustomers) {
          // Check if notification already exists
          const existingNotification = await Notification.findOne({
            userId: employee._id,
            customerId: customer._id,
            type: 'birthday',
            date: {
              $gte: new Date(today.getFullYear(), today.getMonth(), today.getDate()),
              $lt: new Date(today.getFullYear(), today.getMonth(), today.getDate() + 1)
            }
          });

          if (!existingNotification) {
            let title, message;
            if (dateInfo.daysAway === 0) {
              title = "🎂 Birthday Today!";
              message = `${customer.name}'s birthday is today! Send your wishes.`;
            } else if (dateInfo.daysAway === 1) {
              title = "🎂 Birthday Tomorrow!";
              message = `${customer.name}'s birthday is tomorrow! Prepare your wishes.`;
            } else {
              title = `🎂 Upcoming Birthday`;
              message = `${customer.name}'s birthday is in ${dateInfo.daysAway} days.`;
            }

            await Notification.create({
              userId: employee._id,
              customerId: customer._id,
              type: 'birthday',
              title,
              message,
              date: today
            });
          }
        }

        // Find customers with anniversaries in next 7 days
        const anniversaryStr = `${String(dateInfo.day).padStart(2, '0')}-${String(dateInfo.month).padStart(2, '0')}`;
        
        const anniversaryCustomers = await Customer.find({
          anniversary: anniversaryStr
        });

        for (const customer of anniversaryCustomers) {
          const existingNotification = await Notification.findOne({
            userId: employee._id,
            customerId: customer._id,
            type: 'anniversary',
            date: {
              $gte: new Date(today.getFullYear(), today.getMonth(), today.getDate()),
              $lt: new Date(today.getFullYear(), today.getMonth(), today.getDate() + 1)
            }
          });

          if (!existingNotification) {
            let title, message;
            if (dateInfo.daysAway === 0) {
              title = "💍 Anniversary Today!";
              message = `${customer.name}'s anniversary is today! Send your wishes.`;
            } else if (dateInfo.daysAway === 1) {
              title = "💍 Anniversary Tomorrow!";
              message = `${customer.name}'s anniversary is tomorrow! Prepare your wishes.`;
            } else {
              title = `💍 Upcoming Anniversary`;
              message = `${customer.name}'s anniversary is in ${dateInfo.daysAway} days.`;
            }

            await Notification.create({
              userId: employee._id,
              customerId: customer._id,
              type: 'anniversary',
              title,
              message,
              date: today
            });
          }
        }
      }
    }

    console.log("✅ Special day notifications created successfully");
  } catch (err) {
    console.error("❌ Error creating special day notifications:", err);
  }
};