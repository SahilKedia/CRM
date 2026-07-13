const mongoose = require('mongoose');

const notificationSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Employee',
    required: true
  },
  customerId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Customer',
    required: true
  },
  type: {
    type: String,
    enum: ['birthday', 'anniversary', 'reminder'],
    required: true
  },
  title: { type: String, required: true },
  message: { type: String, required: true },
  date: { type: Date, required: true },
  // 👇 NEW: 'YYYY-MM-DD' string for today's date. This is the field that
  // actually stops duplicates — a unique index on it means MongoDB itself
  // will refuse to insert a second birthday/anniversary notification for
  // the same employee+customer+type on the same day, no matter how many
  // times cron runs or how many code paths call it.
  dateKey: { type: String, required: true },
  isRead: { type: Boolean, default: false },
  readAt: { type: Date, default: null },
  isDelivered: { type: Boolean, default: false },
  deliveredAt: { type: Date, default: null }
}, {
  timestamps: true
});

notificationSchema.index({ userId: 1, isRead: 1, date: -1 });
notificationSchema.index({ customerId: 1, type: 1 });

// 🔒 THE ACTUAL DUPLICATE FIX
notificationSchema.index(
  { userId: 1, customerId: 1, type: 1, dateKey: 1 },
  { unique: true }
);

module.exports = mongoose.model('Notification', notificationSchema);