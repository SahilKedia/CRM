const express = require("express");
const router = express.Router();
const { protect } = require("../middleware/auth");
const Notification = require("../models/Notification");

// ==================== CREATE NOTIFICATION ====================
const { toDateKey } = require("../utils/dateHelpers");

// ==================== CREATE NOTIFICATION ====================
router.post("/create", protect, async (req, res) => {
  try {
    const { customerId, type, title, message, date } = req.body;
    const userRole = req.user.role;
    const userBranch = req.user.branch;

    if (!customerId || !type || !title || !message) {
      return res.status(400).json({
        success: false,
        message: "customerId, type, title, and message are required",
      });
    }

    const notifDate = date ? new Date(date) : new Date();
    const dateKey = toDateKey(notifDate);

    let recipientIds = [];

    if (userRole === 'admin') {
      const Employee = require('../models/Employee');
      const employees = await Employee.find({
        $or: [{ branch: userBranch }, { role: 'admin' }]
      }).select('_id');
      recipientIds = employees.map(e => e._id);
    } else {
      recipientIds = [req.user._id];
    }

    const notifications = [];
    for (const userId of recipientIds) {
      try {
        const notification = await Notification.findOneAndUpdate(
          { userId, customerId, type, dateKey },
          {
            $setOnInsert: {
              userId, customerId, type, title, message,
              date: notifDate, dateKey
            }
          },
          { upsert: true, new: true }
        );
        notifications.push(notification);
      } catch (err) {
        if (err.code !== 11000) throw err; // duplicate = already exists, safe to skip
      }
    }

    res.status(201).json({
      success: true,
      message: `Created ${notifications.length} notification(s)`,
      data: notifications,
    });
  } catch (err) {
    console.error("❌ Error creating notification:", err);
    res.status(500).json({
      success: false,
      message: err.message || "Failed to create notification",
    });
  }
});

// Get notifications for logged-in user
// Get notifications for logged-in user
router.get("/", protect, async (req, res) => {
  try {
    const { page = 1, limit = 20, type, isRead } = req.query;
    const userId = req.user._id;
    const userRole = req.user.role;
    const userBranch = req.user.branch;

    console.log('🔍 Fetching notifications for user:', userId);
    console.log('👤 Role:', userRole);
    console.log('🏢 Branch:', userBranch);

    let filter = {};

    // Admin can see all notifications for their branch
    if (userRole === 'admin') {
      // Get all employees in the same branch
      const Employee = require('../models/Employee');
      const employees = await Employee.find({ 
        $or: [
          { branch: userBranch },
          { role: 'admin' }
        ]
      }).select('_id');
      
      const employeeIds = employees.map(e => e._id);
      filter.userId = { $in: employeeIds };
      console.log('👥 Admin can see notifications for employees:', employeeIds.length);
    } else {
      // Regular employee only sees their own notifications
      filter.userId = userId;
    }

    if (type) filter.type = type;
    if (isRead !== undefined) filter.isRead = isRead === 'true';

    console.log('🔍 Filter:', JSON.stringify(filter));

    const notifications = await Notification.find(filter)
      .populate("customerId", "name phone email")
      .sort({ date: -1, createdAt: -1 })
      .skip((page - 1) * limit)
      .limit(Number(limit));

    console.log('📬 Found notifications:', notifications.length);

    const total = await Notification.countDocuments(filter);
    const unreadCount = await Notification.countDocuments({ 
      ...filter, 
      isRead: false 
    });

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
});

// Mark notification as read
router.put("/:id/read", protect, async (req, res) => {
  try {
    const notification = await Notification.findOneAndUpdate(
      { _id: req.params.id, userId: req.user._id },
      { isRead: true, readAt: new Date() },
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
      message: err.message 
    });
  }
});

// Mark all notifications as read
router.put("/mark-all-read", protect, async (req, res) => {
  try {
    await Notification.updateMany(
      { userId: req.user._id, isRead: false },
      { isRead: true, readAt: new Date() }
    );

    res.json({ 
      success: true, 
      message: "All notifications marked as read" 
    });
  } catch (err) {
    console.error("❌ Error marking all notifications as read:", err);
    res.status(500).json({ 
      success: false, 
      message: err.message 
    });
  }
});

// Mark notification as delivered
router.put("/:id/deliver", protect, async (req, res) => {
  try {
    const notification = await Notification.findOneAndUpdate(
      { _id: req.params.id, userId: req.user._id },
      { isDelivered: true, deliveredAt: new Date() },
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
      message: "Notification marked as delivered", 
      data: notification 
    });
  } catch (err) {
    console.error("❌ Error marking notification as delivered:", err);
    res.status(500).json({ 
      success: false, 
      message: err.message 
    });
  }
});

// Delete notification
router.delete("/:id", protect, async (req, res) => {
  try {
    const notification = await Notification.findOneAndDelete({
      _id: req.params.id,
      userId: req.user._id
    });

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
      message: err.message 
    });
  }
});

module.exports = router;